//===--- FrontendTool.cpp - Swift Compiler Frontend -----------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
///
/// \file
/// \brief This is the entry point to the swift -frontend functionality, which
/// implements the core compiler functionality along with a number of additional
/// tools for demonstration and testing purposes.
///
/// This is separate from the rest of libFrontend to reduce the dependencies
/// required by that library.
///
//===----------------------------------------------------------------------===//

#include "swift/FrontendTool/FrontendTool.h"
#include "ImportedModules.h"
#include "ReferenceDependencies.h"
#include "TBD.h"

#include "swift/Strings.h"
#include "swift/Subsystems.h"
#include "swift/AST/ASTScope.h"
#include "swift/AST/DiagnosticsFrontend.h"
#include "swift/AST/DiagnosticsSema.h"
#include "swift/AST/GenericSignatureBuilder.h"
#include "swift/AST/IRGenOptions.h"
#include "swift/AST/ASTMangler.h"
#include "swift/AST/ReferencedNameTracker.h"
#include "swift/AST/TypeRefinementContext.h"
#include "swift/Basic/Dwarf.h"
#include "swift/Basic/Edit.h"
#include "swift/Basic/FileSystem.h"
#include "swift/Basic/JSONSerialization.h"
#include "swift/Basic/LLVMContext.h"
#include "swift/Basic/SourceManager.h"
#include "swift/Basic/Statistic.h"
#include "swift/Basic/Timer.h"
#include "swift/Basic/UUID.h"
#include "swift/Frontend/DiagnosticVerifier.h"
#include "swift/Frontend/Frontend.h"
#include "swift/Frontend/PrintingDiagnosticConsumer.h"
#include "swift/Frontend/SerializedDiagnosticConsumer.h"
#include "swift/Immediate/Immediate.h"
#include "swift/Index/IndexRecord.h"
#include "swift/Option/Options.h"
#include "swift/Migrator/FixitFilter.h"
#include "swift/Migrator/Migrator.h"
#include "swift/PrintAsObjC/PrintAsObjC.h"
#include "swift/Serialization/SerializationOptions.h"
#include "swift/Serialization/SerializedModuleLoader.h"
#include "swift/SILOptimizer/PassManager/Passes.h"
#include "swift/Syntax/Serialization/SyntaxSerialization.h"
#include "swift/Syntax/SyntaxNodes.h"

// FIXME: We're just using CompilerInstance::createOutputFile.
// This API should be sunk down to LLVM.
#include "clang/Frontend/CompilerInstance.h"
#include "clang/APINotes/Types.h"

#include "llvm/ADT/Statistic.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Option/Option.h"
#include "llvm/Option/OptTable.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/Timer.h"
#include "llvm/Support/YAMLTraits.h"
#include "llvm/Target/TargetMachine.h"

#include <deque>
#include <memory>
#include <unordered_set>

#if !defined(_MSC_VER) && !defined(__MINGW32__)
#include <unistd.h>
#else
#include <io.h>
#endif

using namespace swift;

static std::string displayName(StringRef MainExecutablePath) {
  std::string Name = llvm::sys::path::stem(MainExecutablePath);
  Name += " -frontend";
  return Name;
}

/// Emits a Make-style dependencies file.
static bool emitMakeDependencies(DiagnosticEngine &diags,
                                 DependencyTracker &depTracker,
                                 const FrontendOptions &opts,
                                 const InputFile &input) {
  StringRef dependenciesFilePath =
      input.supplementaryOutputs().DependenciesFilePath;
  if (dependenciesFilePath.empty())
    return false;

  std::error_code EC;
  llvm::raw_fd_ostream out(dependenciesFilePath, EC, llvm::sys::fs::F_None);

  if (out.has_error() || EC) {
    diags.diagnose(SourceLoc(), diag::error_opening_output,
                   dependenciesFilePath, EC.message());
    out.clear_error();
    return true;
  }

  // Declare a helper for escaping file names for use in Makefiles.
  llvm::SmallString<256> pathBuf;
  auto escape = [&](StringRef raw) -> StringRef {
    pathBuf.clear();

    static const char badChars[] = " $#:\n";
    size_t prev = 0;
    for (auto index = raw.find_first_of(badChars); index != StringRef::npos;
         index = raw.find_first_of(badChars, index+1)) {
      pathBuf.append(raw.slice(prev, index));
      if (raw[index] == '$')
        pathBuf.push_back('$');
      else
        pathBuf.push_back('\\');
      prev = index;
    }
    pathBuf.append(raw.substr(prev));
    return pathBuf;
  };

  // FIXME: Xcode can't currently handle multiple targets in a single
  // dependency line.
  opts.forAllOutputPaths(input, [&](StringRef targetName) {
    out << escape(targetName) << " :";
    // First include all other files in the module. Make-style dependencies
    // need to be conservative!
    for (auto const &path :
         reversePathSortedFilenames(opts.InputsAndOutputs.getInputFilenames()))
      out << ' ' << escape(path);
    // Then print dependencies we've picked up during compilation.
    for (auto const &path :
           reversePathSortedFilenames(depTracker.getDependencies()))
      out << ' ' << escape(path);
    out << '\n';
  });

  return false;
}

static bool emitMakeDependencies(DiagnosticEngine &diags,
                                 DependencyTracker &depTracker,
                                 const FrontendOptions &opts) {
  bool hadError = false;
  opts.InputsAndOutputs.forEachInputProducingSupplementaryOutput(
      [&](const InputFile &f) -> void {
        hadError = emitMakeDependencies(diags, depTracker, opts, f) || hadError;
      });
  return hadError;
}

namespace {
struct LoadedModuleTraceFormat {
  std::string Name;
  std::string Arch;
  std::vector<std::string> SwiftModules;
};
}

namespace swift {
namespace json {
template <> struct ObjectTraits<LoadedModuleTraceFormat> {
  static void mapping(Output &out, LoadedModuleTraceFormat &contents) {
    out.mapRequired("name", contents.Name);
    out.mapRequired("arch", contents.Arch);
    out.mapRequired("swiftmodules", contents.SwiftModules);
  }
};
}
}

static bool emitLoadedModuleTrace(ASTContext &ctxt,
                                  DependencyTracker &depTracker,
                                  const FrontendOptions &opts,
                                  StringRef loadedModuleTracePath) {
  std::error_code EC;
  llvm::raw_fd_ostream out(loadedModuleTracePath, EC, llvm::sys::fs::F_Append);

  if (out.has_error() || EC) {
    ctxt.Diags.diagnose(SourceLoc(), diag::error_opening_output,
                        loadedModuleTracePath, EC.message());
    out.clear_error();
    return true;
  }

  llvm::SmallVector<std::string, 16> swiftModules;

  // Canonicalise all the paths by opening them.
  for (auto &dep : depTracker.getDependencies()) {
    llvm::SmallString<256> buffer;
    StringRef realPath;
    int FD;
    // FIXME: appropriate error handling
    if (llvm::sys::fs::openFileForRead(dep, FD, &buffer)) {
      // Couldn't open the file now, so let's just assume the old path was
      // canonical (enough).
      realPath = dep;
    } else {
      realPath = buffer.str();
      // Not much we can do about failing to close.
      (void)close(FD);
    }

    // Decide if this is a swiftmodule based on the extension of the raw
    // dependency path, as the true file may have a different one.
    auto ext = llvm::sys::path::extension(dep);
    if (ext.startswith(".") &&
        ext.drop_front() == SERIALIZED_MODULE_EXTENSION) {
      swiftModules.push_back(realPath);
    }
  }

  LoadedModuleTraceFormat trace = {
      /*name=*/opts.ModuleName,
      /*arch=*/ctxt.LangOpts.Target.getArchName(),
      /*swiftmodules=*/reversePathSortedFilenames(swiftModules)};

  // raw_fd_ostream is unbuffered, and we may have multiple processes writing,
  // so first write the whole thing into memory and dump out that buffer to the
  // file.
  std::string stringBuffer;
  {
    llvm::raw_string_ostream memoryBuffer(stringBuffer);
    json::Output jsonOutput(memoryBuffer, /*PrettyPrint=*/false);
    json::jsonize(jsonOutput, trace, /*Required=*/true);
  }
  stringBuffer += "\n";

  out << stringBuffer;

  return true;
}
static bool emitLoadedModuleTrace(ASTContext &ctxt,
                                  DependencyTracker &depTracker,
                                  const FrontendOptions &opts) {
  bool hadError = false;
  opts.InputsAndOutputs.forEachInputProducingSupplementaryOutput(
      [&](const InputFile &f) -> void {
        StringRef p = f.supplementaryOutputs().LoadedModuleTracePath;
        if (!p.empty())
          hadError =
              emitLoadedModuleTrace(ctxt, depTracker, opts, p) || hadError;
      });
  return hadError;
}

/// Gets an output stream for the provided output filename, or diagnoses to the
/// provided AST Context and returns null if there was an error getting the
/// stream.
static std::unique_ptr<llvm::raw_fd_ostream>
getFileOutputStream(StringRef OutputFilename, ASTContext &Ctx) {
  std::error_code errorCode;
  auto os = llvm::make_unique<llvm::raw_fd_ostream>(
              OutputFilename, errorCode, llvm::sys::fs::F_None);
  if (errorCode) {
    Ctx.Diags.diagnose(SourceLoc(), diag::error_opening_output,
                       OutputFilename, errorCode.message());
    return nullptr;
  }
  return os;
}

/// Writes the Syntax tree to the given file
static bool emitSyntax(SourceFile *SF, LangOptions &LangOpts,
                       SourceManager &SM, StringRef OutputFilename) {
  auto bufferID = SF->getBufferID();
  assert(bufferID && "frontend should have a buffer ID "
         "for the main source file");

  auto os = getFileOutputStream(OutputFilename, SF->getASTContext());
  if (!os) return true;

  json::Output jsonOut(*os);
  auto Root = SF->getSyntaxRoot().getRaw();
  jsonOut << Root;
  *os << "\n";
  return false;
}

/// Writes SIL out to the given file.
static bool writeSIL(SILModule &SM, ModuleDecl *M, bool EmitVerboseSIL,
                     StringRef OutputFilename, bool SortSIL) {
  auto OS = getFileOutputStream(OutputFilename, M->getASTContext());
  if (!OS) return true;
  SM.print(*OS, EmitVerboseSIL, M, SortSIL);
  return false;
}

static bool printAsObjC(const std::string &outputPath, ModuleDecl *M,
                        StringRef bridgingHeader, bool moduleIsPublic) {
  using namespace llvm::sys;

  clang::CompilerInstance Clang;

  std::string tmpFilePath;
  std::error_code EC;
  std::unique_ptr<llvm::raw_pwrite_stream> out =
    Clang.createOutputFile(outputPath, EC,
                           /*Binary=*/false,
                           /*RemoveFileOnSignal=*/true,
                           /*BaseInput=*/"",
                           path::extension(outputPath),
                           /*UseTemporary=*/true,
                           /*CreateMissingDirectories=*/false,
                           /*ResultPathName=*/nullptr,
                           &tmpFilePath);

  if (!out) {
    M->getASTContext().Diags.diagnose(SourceLoc(), diag::error_opening_output,
                                      tmpFilePath, EC.message());
    return true;
  }

  auto requiredAccess = moduleIsPublic ? AccessLevel::Public
                                       : AccessLevel::Internal;
  bool hadError = printAsObjC(*out, M, bridgingHeader, requiredAccess);
  out->flush();

  EC = swift::moveFileIfDifferent(tmpFilePath, outputPath);
  if (EC) {
    M->getASTContext().Diags.diagnose(SourceLoc(), diag::error_opening_output,
                                      outputPath, EC.message());
    return true;
  }

  return hadError;
}

/// Returns the OutputKind for the given Action.
static IRGenOutputKind getOutputKind(FrontendOptions::ActionType Action) {
  switch (Action) {
  case FrontendOptions::ActionType::EmitIR:
    return IRGenOutputKind::LLVMAssembly;
  case FrontendOptions::ActionType::EmitBC:
    return IRGenOutputKind::LLVMBitcode;
  case FrontendOptions::ActionType::EmitAssembly:
    return IRGenOutputKind::NativeAssembly;
  case FrontendOptions::ActionType::EmitObject:
    return IRGenOutputKind::ObjectFile;
  case FrontendOptions::ActionType::Immediate:
    return IRGenOutputKind::Module;
  default:
    llvm_unreachable("Unknown ActionType which requires IRGen");
    return IRGenOutputKind::ObjectFile;
  }
}

namespace {

/// If there is an error with fixits it writes the fixits as edits in json
/// format.
class JSONFixitWriter
  : public DiagnosticConsumer, public migrator::FixitFilter {
  std::string FixitsOutputPath;
  std::unique_ptr<llvm::raw_ostream> OSPtr;
  bool FixitAll;
  std::vector<SingleEdit> AllEdits;

public:
  JSONFixitWriter(std::string fixitsOutputPath,
                  const DiagnosticOptions &DiagOpts)
    : FixitsOutputPath(fixitsOutputPath),
      FixitAll(DiagOpts.FixitCodeForAllDiagnostics) {}

private:
  void handleDiagnostic(SourceManager &SM, SourceLoc Loc,
                        DiagnosticKind Kind,
                        StringRef FormatString,
                        ArrayRef<DiagnosticArgument> FormatArgs,
                        const DiagnosticInfo &Info) override {
    if (!(FixitAll || shouldTakeFixit(Kind, Info)))
      return;
    for (const auto &Fix : Info.FixIts) {
      AllEdits.push_back({SM, Fix.getRange(), Fix.getText()});
    }
  }

  bool finishProcessing() override {
    std::error_code EC;
    std::unique_ptr<llvm::raw_fd_ostream> OS;
    OS.reset(new llvm::raw_fd_ostream(FixitsOutputPath,
                                      EC,
                                      llvm::sys::fs::F_None));
    if (EC) {
      // Create a temporary diagnostics engine to print the error to stderr.
      SourceManager dummyMgr;
      DiagnosticEngine DE(dummyMgr);
      PrintingDiagnosticConsumer PDC;
      DE.addConsumer(PDC);
      DE.diagnose(SourceLoc(), diag::cannot_open_file,
                  FixitsOutputPath, EC.message());
      return true;
    }

    swift::writeEditsInJson(llvm::makeArrayRef(AllEdits), *OS);
    return false;
  }
};

} // anonymous namespace

// This is a separate function so that it shows up in stack traces.
LLVM_ATTRIBUTE_NOINLINE
static void debugFailWithAssertion() {
  // Per the user's request, this assertion should always fail in
  // builds with assertions enabled.

  // This should not be converted to llvm_unreachable, as those are
  // treated as optimization hints in builds where they turn into
  // __builtin_unreachable().
  assert((0) && "This is an assertion!");
}

// This is a separate function so that it shows up in stack traces.
LLVM_ATTRIBUTE_NOINLINE
static void debugFailWithCrash() {
  LLVM_BUILTIN_TRAP;
}

static bool emitIndexData(SourceFile *PrimarySourceFile,
      const CompilerInvocation &Invocation,
      CompilerInstance &Instance);

static void countStatsOfSourceFile(UnifiedStatsReporter &Stats,
                                   CompilerInstance &Instance,
                                   SourceFile *SF) {
  auto &C = Stats.getFrontendCounters();
  auto &SM = Instance.getSourceMgr();
  C.NumDecls += SF->Decls.size();
  C.NumLocalTypeDecls += SF->LocalTypeDecls.size();
  C.NumObjCMethods += SF->ObjCMethods.size();
  C.NumInfixOperators += SF->InfixOperators.size();
  C.NumPostfixOperators += SF->PostfixOperators.size();
  C.NumPrefixOperators += SF->PrefixOperators.size();
  C.NumPrecedenceGroups += SF->PrecedenceGroups.size();
  C.NumUsedConformances += SF->getUsedConformances().size();

  auto bufID = SF->getBufferID();
  if (bufID.hasValue()) {
    C.NumSourceLines +=
      SM.getEntireTextForBuffer(bufID.getValue()).count('\n');
  }
}

static void countStatsPostSema(UnifiedStatsReporter &Stats,
                               CompilerInstance& Instance) {
  auto &C = Stats.getFrontendCounters();
  auto &SM = Instance.getSourceMgr();
  C.NumSourceBuffers = SM.getLLVMSourceMgr().getNumBuffers();
  C.NumLinkLibraries = Instance.getLinkLibraries().size();

  auto const &AST = Instance.getASTContext();
  C.NumLoadedModules = AST.LoadedModules.size();
  C.NumImportedExternalDefinitions = AST.ExternalDefinitions.size();
  C.NumASTBytesAllocated = AST.getAllocator().getBytesAllocated();

  if (auto *D = Instance.getDependencyTracker()) {
    C.NumDependencies = D->getDependencies().size();
  }

  for (auto SF : Instance.getPrimarySourceFiles()) {
    if (auto *R = SF->getReferencedNameTracker()) {
      C.NumReferencedTopLevelNames = R->getTopLevelNames().size();
      C.NumReferencedDynamicNames = R->getDynamicLookupNames().size();
      C.NumReferencedMemberNames = R->getUsedMembers().size();
    }
  }

  if (!Instance.getPrimarySourceFiles().empty()) {
    for (auto SF : Instance.getPrimarySourceFiles())
      countStatsOfSourceFile(Stats, Instance, SF);
  } else if (auto *M = Instance.getMainModule()) {
    // No primary source file, but a main module; this is WMO-mode
    for (auto *F : M->getFiles()) {
      if (auto *SF = dyn_cast<SourceFile>(F)) {
        countStatsOfSourceFile(Stats, Instance, SF);
      }
    }
  }
}

static void countStatsPostSILGen(UnifiedStatsReporter &Stats,
                                 const SILModule& Module) {
  auto &C = Stats.getFrontendCounters();
  // FIXME: calculate these in constant time, via the dense maps.
  C.NumSILGenFunctions = Module.getFunctionList().size();
  C.NumSILGenVtables = Module.getVTableList().size();
  C.NumSILGenWitnessTables = Module.getWitnessTableList().size();
  C.NumSILGenDefaultWitnessTables = Module.getDefaultWitnessTableList().size();
  C.NumSILGenGlobalVariables = Module.getSILGlobalList().size();
}

static void countStatsPostSILOpt(UnifiedStatsReporter &Stats,
                                 const SILModule& Module) {
  auto &C = Stats.getFrontendCounters();
  // FIXME: calculate these in constant time, via the dense maps.
  C.NumSILOptFunctions = Module.getFunctionList().size();
  C.NumSILOptVtables = Module.getVTableList().size();
  C.NumSILOptWitnessTables = Module.getWitnessTableList().size();
  C.NumSILOptDefaultWitnessTables = Module.getDefaultWitnessTableList().size();
  C.NumSILOptGlobalVariables = Module.getSILGlobalList().size();
}

static std::unique_ptr<llvm::raw_fd_ostream>
createOptRecordFile(StringRef Filename, DiagnosticEngine &DE) {
  if (Filename.empty())
    return nullptr;

  std::error_code EC;
  auto File = llvm::make_unique<llvm::raw_fd_ostream>(Filename, EC,
                                                      llvm::sys::fs::F_None);
  if (EC) {
    DE.diagnose(SourceLoc(), diag::cannot_open_file, Filename, EC.message());
    return nullptr;
  }
  return File;
}

struct PostSILGenInputs {
  std::unique_ptr<SILModule> TheSILModule;
  bool ASTGuaranteedToCorrespondToSIL;
  ModuleOrSourceFile ModuleOrPrimarySourceFile;
};

static bool precompileBridgingHeader(CompilerInvocation &Invocation,
                                     CompilerInstance &Instance) {
  auto clangImporter = static_cast<ClangImporter *>(
      Instance.getASTContext().getClangModuleLoader());
  auto &ImporterOpts = Invocation.getClangImporterOptions();
  auto &PCHOutDir = ImporterOpts.PrecompiledHeaderOutputDir;
  if (!PCHOutDir.empty()) {
    ImporterOpts.BridgingHeader =
        Invocation.getFrontendOptions()
            .InputsAndOutputs.getFilenameOfFirstInput();
    // Create or validate a persistent PCH.
    auto SwiftPCHHash = Invocation.getPCHHash();
    auto PCH = clangImporter->getOrCreatePCH(ImporterOpts, SwiftPCHHash);
    return !PCH.hasValue();
  }
  return clangImporter->emitBridgingPCH(
      Invocation.getFrontendOptions()
          .InputsAndOutputs.getFilenameOfFirstInput(),
      Invocation.getFrontendOptions()
          .InputsAndOutputs.getSingleOutputFilename());
}

static bool compileLLVMIr(CompilerInvocation &Invocation,
                          CompilerInstance &Instance,
                          UnifiedStatsReporter *Stats) {
  auto &LLVMContext = getGlobalLLVMContext();

  // Load in bitcode file.
  assert(Invocation.getFrontendOptions().InputsAndOutputs.hasSingleInput() &&
         "We expect a single input for bitcode input!");
  llvm::ErrorOr<std::unique_ptr<llvm::MemoryBuffer>> FileBufOrErr =
      llvm::MemoryBuffer::getFileOrSTDIN(
          Invocation.getFrontendOptions()
              .InputsAndOutputs.getFilenameOfFirstInput());
  if (!FileBufOrErr) {
    Instance.getASTContext().Diags.diagnose(
        SourceLoc(), diag::error_open_input_file,
        Invocation.getFrontendOptions()
            .InputsAndOutputs.getFilenameOfFirstInput(),
        FileBufOrErr.getError().message());
    return true;
  }
  llvm::MemoryBuffer *MainFile = FileBufOrErr.get().get();

  llvm::SMDiagnostic Err;
  std::unique_ptr<llvm::Module> Module =
      llvm::parseIR(MainFile->getMemBufferRef(), Err, LLVMContext);
  if (!Module) {
    // TODO: Translate from the diagnostic info to the SourceManager location
    // if available.
    Instance.getASTContext().Diags.diagnose(
        SourceLoc(), diag::error_parse_input_file,
        Invocation.getFrontendOptions()
            .InputsAndOutputs.getFilenameOfFirstInput(),
        Err.getMessage());
    return true;
  }
  IRGenOptions &IRGenOpts = Invocation.getIRGenOptions();
  // TODO: remove once the frontend understands what action it should perform
  IRGenOpts.OutputKind =
      getOutputKind(Invocation.getFrontendOptions().RequestedAction);

  return performLLVM(IRGenOpts, Instance.getASTContext(), Module.get(),
                     Invocation.getFrontendOptions()
                         .InputsAndOutputs.getSingleOutputFilename(),
                     Stats);
}

static Optional<bool> performParseOrSema(CompilerInstance &Instance,
                                         FrontendOptions::ActionType Action) {
  if (Action == FrontendOptions::ActionType::Parse ||
      Action == FrontendOptions::ActionType::DumpParse ||
      Action == FrontendOptions::ActionType::EmitSyntax ||
      Action == FrontendOptions::ActionType::DumpInterfaceHash ||
      Action == FrontendOptions::ActionType::EmitImportedModules)
    Instance.performParseOnly();
  else
    Instance.performSema();

  return Action == FrontendOptions::ActionType::Parse
             ? Optional<bool>(Instance.getASTContext().hadError())
             : None;
}

static void crashIfNeeded(FrontendOptions::DebugCrashMode CrashMode) {
  if (CrashMode == FrontendOptions::DebugCrashMode::AssertAfterParse)
    debugFailWithAssertion();
  else if (CrashMode == FrontendOptions::DebugCrashMode::CrashAfterParse)
    debugFailWithCrash();
}

static void verifyGenericSignatures(CompilerInvocation &Invocation,
                                    ASTContext &Context) {
  auto verifyGenericSignaturesInModule =
      Invocation.getFrontendOptions().VerifyGenericSignaturesInModule;
  if (!verifyGenericSignaturesInModule.empty()) {
    if (auto module = Context.getModuleByName(verifyGenericSignaturesInModule))
      GenericSignatureBuilder::verifyGenericSignaturesInModule(module);
  }
}

static void dumpOneScopeMapLocation(unsigned bufferID,
                                    std::pair<unsigned, unsigned> lineColumn,
                                    SourceManager &sourceMgr, ASTScope &scope) {
  SourceLoc loc =
      sourceMgr.getLocForLineCol(bufferID, lineColumn.first, lineColumn.second);
  if (loc.isInvalid())
    return;

  llvm::errs() << "***Scope at " << lineColumn.first << ":" << lineColumn.second
               << "***\n";
  auto locScope = scope.findInnermostEnclosingScope(loc);
  locScope->print(llvm::errs(), 0, false, false);

  // Dump the AST context, too.
  if (auto dc = locScope->getDeclContext()) {
    dc->printContext(llvm::errs());
  }

  // Grab the local bindings introduced by this scope.
  auto localBindings = locScope->getLocalBindings();
  if (!localBindings.empty()) {
    llvm::errs() << "Local bindings: ";
    interleave(localBindings.begin(), localBindings.end(),
               [&](ValueDecl *value) { llvm::errs() << value->getFullName(); },
               [&]() { llvm::errs() << " "; });
    llvm::errs() << "\n";
  }
}

static void dumpAndPrintScopeMap(CompilerInvocation &Invocation,
                                 CompilerInstance &Instance, SourceFile *SF) {
  ASTScope &scope = SF->getScope();

  if (Invocation.getFrontendOptions().DumpScopeMapLocations.empty()) {
    scope.expandAll();
  } else if (auto bufferID = SF->getBufferID()) {
    SourceManager &sourceMgr = Instance.getSourceMgr();
    // Probe each of the locations, and dump what we find.
    for (auto lineColumn :
         Invocation.getFrontendOptions().DumpScopeMapLocations)
      dumpOneScopeMapLocation(*bufferID, lineColumn, sourceMgr, scope);

    llvm::errs() << "***Complete scope map***\n";
  }
  // Print the resulting map.
  scope.print(llvm::errs());
}

static SourceFile *getPrimaryOrMainSourceFile(CompilerInvocation &Invocation,
                                              CompilerInstance &Instance) {
  SourceFile *SF = Instance.getPrimarySourceFile();
  if (!SF) {
    SourceFileKind Kind = Invocation.getSourceFileKind();
    SF = &Instance.getMainModule()->getMainSourceFile(Kind);
  }
  return SF;
}

/// We've been told to dump the AST (either after parsing or type-checking,
/// which is already differentiated in CompilerInstance::performSema()),
/// so dump or print the main source file and return.

static Optional<bool> dumpAST(CompilerInvocation &Invocation,
                              CompilerInstance &Instance) {
  FrontendOptions &opts = Invocation.getFrontendOptions();
  FrontendOptions::ActionType Action = opts.RequestedAction;
  ASTContext &Context = Instance.getASTContext();

  switch (Action) {
  default:
    return None;

  case FrontendOptions::ActionType::EmitImportedModules:
    emitImportedModules(Context, Instance.getMainModule(), opts);
    break;

  case FrontendOptions::ActionType::PrintAST:
    getPrimaryOrMainSourceFile(Invocation, Instance)
        ->print(llvm::outs(), PrintOptions::printEverything());
    break;

  case FrontendOptions::ActionType::DumpScopeMaps:
    dumpAndPrintScopeMap(Invocation, Instance,
                         getPrimaryOrMainSourceFile(Invocation, Instance));
    break;

  case FrontendOptions::ActionType::DumpTypeRefinementContexts:
    getPrimaryOrMainSourceFile(Invocation, Instance)
        ->getTypeRefinementContext()
        ->dump(llvm::errs(), Context.SourceMgr);
    break;

  case FrontendOptions::ActionType::DumpInterfaceHash:
    getPrimaryOrMainSourceFile(Invocation, Instance)
        ->dumpInterfaceHash(llvm::errs());
    break;

  case FrontendOptions::ActionType::EmitSyntax:
    emitSyntax(getPrimaryOrMainSourceFile(Invocation, Instance),
               Invocation.getLangOptions(), Instance.getSourceMgr(),
               opts.InputsAndOutputs.getSingleOutputFilename());
    break;

  case FrontendOptions::ActionType::DumpParse:
  case FrontendOptions::ActionType::DumpAST:
    getPrimaryOrMainSourceFile(Invocation, Instance)->dump();
    break;
  }
  return Context.hadError();
}

static void emitReferenceDependencies(CompilerInvocation &Invocation,
                                      CompilerInstance &Instance) {
  if (Invocation.getFrontendOptions()
          .InputsAndOutputs.hasReferenceDependenciesPath() &&
      Instance.getPrimarySourceFiles().empty()) {
    Instance.getASTContext().Diags.diagnose(
        SourceLoc(), diag::emit_reference_dependencies_without_primary_file);
    return;
  }
  for (auto *SF : Instance.getPrimarySourceFiles()) {
    emitReferenceDependencies(Instance.getASTContext().Diags, SF,
                              *Instance.getDependencyTracker(),
                              Invocation.getFrontendOptions());
  }
}

static bool finishTypecheck(CompilerInvocation &Invocation,
                            CompilerInstance &Instance, bool moduleIsPublic) {
  FrontendOptions &opts = Invocation.getFrontendOptions();
  if (opts.InputsAndOutputs.hasObjCHeaderOutputPath())
    return printAsObjC(opts.InputsAndOutputs.getObjCHeaderOutputPath(),
                       Instance.getMainModule(), opts.ImplicitObjCHeaderPath,
                       moduleIsPublic);
  if (!opts.IndexStorePath.empty()) {
    if (emitIndexData(Instance.getPrimarySourceFile(), Invocation, Instance))
      return true;
  }
  return Instance.getASTContext().hadError();
}

static bool writeTBDIfNeeded(CompilerInvocation &Invocation,
                             CompilerInstance &Instance) {
  bool hadError = false;
  Invocation.getFrontendOptions()
      .InputsAndOutputs.forEachInputProducingSupplementaryOutput(
          [&](const InputFile &input) -> void {
            StringRef TBDPath = input.supplementaryOutputs().TBDPath;
            if (TBDPath.empty())
              return;
            auto installName =
                Invocation.getFrontendOptions().TBDInstallName.empty()
                    ? "lib" + Invocation.getModuleName().str() + ".dylib"
                    : Invocation.getFrontendOptions().TBDInstallName;

            hadError = writeTBD(Instance.getMainModule(),
                                Invocation.getSILOptions().hasMultipleIGMs(),
                                TBDPath, installName) ||
                       hadError;
          });
  return hadError;
}

static std::deque<PostSILGenInputs>
generateSILModules(CompilerInvocation &Invocation, CompilerInstance &Instance) {
  auto mod = Instance.getMainModule();
  if (auto SM = Instance.takeSILModule()) {
    std::deque<PostSILGenInputs> PSGIs;
    PSGIs.push_back(PostSILGenInputs{std::move(SM), false, mod});
    return PSGIs;
  }

  SILOptions &SILOpts = Invocation.getSILOptions();
  FrontendOptions &opts = Invocation.getFrontendOptions();
  auto fileIsSIB = [](const FileUnit *File) -> bool {
    auto SASTF = dyn_cast<SerializedASTFile>(File);
    return SASTF && SASTF->isSIB();
  };

  if (!opts.InputsAndOutputs.hasPrimaryInputs()) {
    // If we have no primary inputs we are in WMO mode and need to build a
    // SILModule for the entire module.
    auto SM =
        performSILGeneration(mod, SILOpts, Instance.getPSPsForWMO(), true);
    std::deque<PostSILGenInputs> PSGIs;
    PSGIs.push_back(PostSILGenInputs{
        std::move(SM), llvm::none_of(mod->getFiles(), fileIsSIB), mod});
    return PSGIs;
  }
  // If we primary source files, build a separate SILModule for
  // each source file, and run the remaining SILOpt-Serialize-IRGen-LLVM
  // once for each such input.
  std::deque<PostSILGenInputs> PSGIs;
  for (auto *PrimaryFile : Instance.getPrimarySourceFiles()) {
    auto SM = performSILGeneration(
        *PrimaryFile, SILOpts,
        Instance.getPSPsForPrimary(PrimaryFile->getFilename()), None);
    PSGIs.push_back(
        PostSILGenInputs{std::move(SM), !fileIsSIB(PrimaryFile), PrimaryFile});
  }
  if (!PSGIs.empty())
    return PSGIs;

  // If we have primary inputs but no primary _source files_, we might
  // have a primary serialized input.
  for (FileUnit *fileUnit : mod->getFiles()) {
    if (auto SASTF = dyn_cast<SerializedASTFile>(fileUnit))
      if (Invocation.getFrontendOptions().InputsAndOutputs.isFilePrimary(
              SASTF->getFilename())) {
        assert(PSGIs.empty() && "Can only handle one primary AST input");
        auto SM = performSILGeneration(
            *SASTF, SILOpts, Instance.getPSPsForPrimary(SASTF->getFilename()),
            None);
        PSGIs.push_back(
            PostSILGenInputs{std::move(SM), !fileIsSIB(SASTF), mod});
      }
  }
  return PSGIs;
}

static bool performCompileStepsPostSILGen(
    CompilerInstance &Instance, CompilerInvocation &Invocation,
    std::unique_ptr<SILModule> SM, bool astGuaranteedToCorrespondToSIL,
    ModuleOrSourceFile MSF, bool moduleIsPublic, int &ReturnValue,
    FrontendObserver *observer, UnifiedStatsReporter *Stats);

/// Performs the compile requested by the user.
/// \param Instance Will be reset after performIRGeneration when the verifier
///                 mode is NoVerify and there were no errors.
/// \returns true on error
static bool performCompile(CompilerInstance &Instance,
                           CompilerInvocation &Invocation,
                           ArrayRef<const char *> Args,
                           int &ReturnValue,
                           FrontendObserver *observer,
                           UnifiedStatsReporter *Stats) {
  FrontendOptions opts = Invocation.getFrontendOptions();
  FrontendOptions::ActionType Action = opts.RequestedAction;

  if (Action == FrontendOptions::ActionType::EmitSyntax) {
    Instance.getASTContext().LangOpts.KeepSyntaxInfoInSourceFile = true;
    Instance.getASTContext().LangOpts.VerifySyntaxTree = true;
  }

  // We've been asked to precompile a bridging header; we want to
  // avoid touching any other inputs and just parse, emit and exit.
  if (Action == FrontendOptions::ActionType::EmitPCH)
    return precompileBridgingHeader(Invocation, Instance);

  {
    bool inputIsLLVMIr =
        Invocation.getInputKind() == InputFileKind::IFK_LLVM_IR;
    if (inputIsLLVMIr)
      return compileLLVMIr(Invocation, Instance, Stats);
  }

  if (auto r = performParseOrSema(Instance, Action))
    return *r;

  if (observer) {
    observer->performedSemanticAnalysis(Instance);
  }

  if (Stats) {
    countStatsPostSema(*Stats, Instance);
  }

  crashIfNeeded(opts.CrashMode);

  ASTContext &Context = Instance.getASTContext();

  verifyGenericSignatures(Invocation, Context);

  if (Invocation.getMigratorOptions().shouldRunMigrator()) {
    migrator::updateCodeAndEmitRemap(&Instance, Invocation);
  }

  if (Action == FrontendOptions::ActionType::REPL) {
    runREPL(Instance, ProcessCmdLine(Args.begin(), Args.end()),
            Invocation.getParseStdlib());
    return Context.hadError();
  }

  if (auto r = dumpAST(Invocation, Instance))
    return *r;

  // If we were asked to print Clang stats, do so.
  if (opts.PrintClangStats && Context.getClangModuleLoader())
    Context.getClangModuleLoader()->printStatistics();

  (void)emitMakeDependencies(Context.Diags, *Instance.getDependencyTracker(),
                             opts);

  emitReferenceDependencies(Invocation, Instance);

  (void)emitLoadedModuleTrace(Context, *Instance.getDependencyTracker(), opts);

  bool shouldIndex = !opts.IndexStorePath.empty();

  if (Context.hadError()) {
    if (shouldIndex) {
      //  Emit the index store data even if there were compiler errors.
      (void)emitIndexData(Instance.getPrimarySourceFile(), Invocation,
                          Instance);
    }
    return true;
  }

  // FIXME: This is still a lousy approximation of whether the module file will
  // be externally consumed.
  bool moduleIsPublic =
      !Instance.getMainModule()->hasEntryPoint() &&
      opts.ImplicitObjCHeaderPath.empty() &&
      !Context.LangOpts.EnableAppExtensionRestrictions;

  // We've just been told to perform a typecheck, so we can return now.
  if (Action == FrontendOptions::ActionType::Typecheck)
    return finishTypecheck(Invocation, Instance, moduleIsPublic);

  if (writeTBDIfNeeded(Invocation, Instance))
    return true;

  assert(Action >= FrontendOptions::ActionType::EmitSILGen &&
         "All actions not requiring SILGen must have been handled!");

  std::deque<PostSILGenInputs> PSGIs = generateSILModules(Invocation, Instance);

  while (!PSGIs.empty()) {
    auto PSGI = std::move(PSGIs.front());
    PSGIs.pop_front();
    if (performCompileStepsPostSILGen(
            Instance, Invocation, std::move(PSGI.TheSILModule),
            PSGI.ASTGuaranteedToCorrespondToSIL, PSGI.ModuleOrPrimarySourceFile,
            moduleIsPublic, ReturnValue, observer, Stats))
      return true;
  }
  return false;
}

static Optional<bool> emitSILAfterSILGen(CompilerInvocation &Invocation,
                                         CompilerInstance &Instance,
                                         SILModule *SM) {
  // We've been told to emit SIL after SILGen, so write it now.
  FrontendOptions &opts = Invocation.getFrontendOptions();
  if (opts.RequestedAction != FrontendOptions::ActionType::EmitSILGen)
    return None;
  // If we are asked to link all, link all.
  if (Invocation.getSILOptions().LinkMode == SILOptions::LinkAll)
    performSILLinking(SM, true);
  return writeSIL(*SM, Instance.getMainModule(), opts.EmitVerboseSIL,
                  SM->getPSPs().OutputFilename, opts.EmitSortedSIL);
}

static bool serializeMSF(FrontendInputsAndOutputs &inputsAndOutputs,
                         SILModule *SM, ASTContext &Context,
                         ModuleOrSourceFile MSF) {
  const std::string &moduleOutputPath =
      SM->getPSPs().SupplementaryOutputs.ModuleOutputPath;
  if (moduleOutputPath.empty())
    return Context.hadError();
  SerializationOptions serializationOpts;
  serializationOpts.OutputPath = moduleOutputPath.c_str();
  serializationOpts.SerializeAllSIL = true;
  serializationOpts.IsSIB = true;
  serialize(MSF, serializationOpts, SM);
  return Context.hadError();
}

static Optional<bool> emitSIBAfterSILGen(CompilerInvocation &Invocation,
                                         CompilerInstance &Instance,
                                         SILModule *SM,
                                         ModuleOrSourceFile MSF) {
  if (Invocation.getFrontendOptions().RequestedAction !=
      FrontendOptions::ActionType::EmitSIBGen)
    return None;
  // If we are asked to link all, link all.
  if (Invocation.getSILOptions().LinkMode == SILOptions::LinkAll)
    performSILLinking(SM, true);

  return serializeMSF(Invocation.getFrontendOptions().InputsAndOutputs, SM,
                      Instance.getASTContext(), MSF);
}

static Optional<bool>
emitSIBIFNeededAfterOptimizations(CompilerInvocation &Invocation, SILModule *SM,
                                  ASTContext &Context, ModuleOrSourceFile MSF) {
  FrontendOptions &opts = Invocation.getFrontendOptions();
  return opts.RequestedAction != FrontendOptions::ActionType::EmitSIB
             ? Optional<bool>()
             : serializeMSF(opts.InputsAndOutputs, SM, Context, MSF);
}

/// Perform "stable" optimizations that are invariant across compiler versions.
static bool performStableOptimizations(CompilerInvocation &Invocation,
                                       SILModule *SM,
                                       FrontendObserver *observer) {
  // Perform "stable" optimizations that are invariant across compiler versions.
  if (Invocation.getFrontendOptions().RequestedAction ==
      FrontendOptions::ActionType::MergeModules) {
    // Don't run diagnostic passes at all.
  } else if (!Invocation.getDiagnosticOptions().SkipDiagnosticPasses) {
    if (runSILDiagnosticPasses(*SM))
      return true;

    if (observer) {
      observer->performedSILDiagnostics(*SM);
    }
  } else {
    // Even if we are not supposed to run the diagnostic passes, we still need
    // to run the ownership evaluator.
    if (runSILOwnershipEliminatorPass(*SM))
      return true;
  }

  // Now if we are asked to link all, link all.
  if (Invocation.getSILOptions().LinkMode == SILOptions::LinkAll)
    performSILLinking(SM, true);

  if (Invocation.getSILOptions().MergePartialModules)
    SM->linkAllFromCurrentModule();
  return false;
}

/// Perform SIL optimization passes if optimizations haven't been disabled.
/// These may change across compiler versions.
static void performAndTimeSILOptimization(CompilerInvocation &Invocation,
                                          SILModule *SM) {
  SharedTimer timer("SIL optimization");
  if (Invocation.getFrontendOptions().RequestedAction ==
          FrontendOptions::ActionType::MergeModules ||
      !Invocation.getSILOptions().shouldOptimize()) {
    runSILPassesForOnone(*SM);
    return;
  }
  runSILOptPreparePasses(*SM);

  StringRef CustomPipelinePath =
      Invocation.getSILOptions().ExternalPassPipelineFilename;
  if (!CustomPipelinePath.empty()) {
    runSILOptimizationPassesWithFileSpecification(*SM, CustomPipelinePath);
  } else {
    runSILOptimizationPasses(*SM);
  }
}

/// Gather instruction counts if we are asked to do so.
static void gatherInstructionCounts(SILModule *SM) {
  if (SM->getOptions().PrintInstCounts)
    performSILInstCount(&*SM);
}

/// Get the main source file's private discriminator and attach it to
/// the compile unit's flags.
static void setMSFPrivateDiscriminator(IRGenOptions &IRGenOpts,
                                       ModuleOrSourceFile MSF) {
  if (IRGenOpts.DebugInfoKind == IRGenDebugInfoKind::None ||
      !MSF.is<SourceFile *>())
    return;
  Identifier PD = MSF.get<SourceFile *>()->getPrivateDiscriminator();
  if (!PD.empty())
    IRGenOpts.DWARFDebugFlags += (" -private-discriminator " + PD.str()).str();
}

static void writeObjCHeader(CompilerInvocation &Invocation,
                            ModuleDecl *mainModule, bool moduleIsPublic,
                            PrimarySpecificPaths PSPs) {
  FrontendOptions &opts = Invocation.getFrontendOptions();
  StringRef outputPath = PSPs.SupplementaryOutputs.ObjCHeaderOutputPath;
  if (outputPath.empty())
    return;
  (void)printAsObjC(opts.InputsAndOutputs.getObjCHeaderOutputPath(), mainModule,
                    opts.ImplicitObjCHeaderPath, moduleIsPublic);
}

static Optional<bool> emitModuleIfNeeded(SILModule *SM,
                                         CompilerInvocation &Invocation,
                                         CompilerInstance &Instance,
                                         ModuleOrSourceFile MSF) {
  const SupplementaryOutputPaths &outs = SM->getPSPs().SupplementaryOutputs;

  if (outs.ModuleOutputPath.empty() && outs.ModuleDocOutputPath.empty())
    return None;

  // Serialize the SILModule if it was not serialized yet.
  if (!SM->isSerialized())
    SM->serialize();
  auto action = Invocation.getFrontendOptions().RequestedAction;
  if (action != FrontendOptions::ActionType::MergeModules &&
      action != FrontendOptions::ActionType::EmitModuleOnly)
    return None;

  if (Invocation.getFrontendOptions().IndexStorePath.empty())
    return Instance.getASTContext().hadError();

  return emitIndexData(MSF.dyn_cast<SourceFile *>(), Invocation, Instance) ||
         Instance.getASTContext().hadError();
}

static bool setUpForAndRunImmediately(CompilerInvocation &Invocation,
                                      CompilerInstance &Instance,
                                      std::unique_ptr<SILModule> SM,
                                      ModuleOrSourceFile MSF,
                                      FrontendObserver *observer,
                                      int &ReturnValue) {
  FrontendOptions &opts = Invocation.getFrontendOptions();
  assert(!MSF.is<SourceFile *>() && "-i doesn't work in -primary-file mode");
  IRGenOptions &IRGenOpts = Invocation.getIRGenOptions();
  IRGenOpts.UseJIT = true;
  IRGenOpts.DebugInfoKind = IRGenDebugInfoKind::Normal;
  const ProcessCmdLine &CmdLine =
      ProcessCmdLine(opts.ImmediateArgv.begin(), opts.ImmediateArgv.end());
  Instance.setSILModule(std::move(SM));

  if (observer) {
    observer->aboutToRunImmediately(Instance);
  }

  ReturnValue =
      RunImmediately(Instance, CmdLine, IRGenOpts, Invocation.getSILOptions());
  return Instance.getASTContext().hadError();
}

static std::pair<std::unique_ptr<llvm::Module>, llvm::GlobalVariable *>
generateIR(IRGenOptions &IRGenOpts, std::unique_ptr<SILModule> SM,
           StringRef OutputFilename, ModuleOrSourceFile MSF) {
  // FIXME: We shouldn't need to use the global context here, but
  // something is persisting across calls to performIRGeneration.
  auto &LLVMContext = getGlobalLLVMContext();
  llvm::GlobalVariable *HashGlobal;
  std::unique_ptr<llvm::Module> IRModule =
      MSF.is<SourceFile *>()
          ? performIRGeneration(IRGenOpts, *MSF.get<SourceFile *>(),
                                std::move(SM), OutputFilename, LLVMContext, 0,
                                &HashGlobal)
          : performIRGeneration(IRGenOpts, MSF.get<ModuleDecl *>(),
                                std::move(SM), OutputFilename, LLVMContext,
                                &HashGlobal);

  return make_pair(std::move(IRModule), HashGlobal);
}

static bool walkASTForIndexing(CompilerInvocation &Invocation,
                               CompilerInstance &Instance,
                               ModuleOrSourceFile MSF) {
  return !Invocation.getFrontendOptions().IndexStorePath.empty() &&
         emitIndexData(MSF.dyn_cast<SourceFile *>(), Invocation, Instance);
}

static bool validateTBDIfNeeded(CompilerInvocation &Invocation,
                                ModuleOrSourceFile MSF,
                                bool astGuaranteedToCorrespondToSIL,
                                llvm::Module &IRModule) {
  const auto mode = Invocation.getFrontendOptions().ValidateTBDAgainstIR;
  switch (mode) {
  case FrontendOptions::TBDValidationMode::None:
    return false;
  case FrontendOptions::TBDValidationMode::All:
  case FrontendOptions::TBDValidationMode::MissingFromTBD: {
    if (!inputFileKindCanHaveTBDValidated(Invocation.getInputKind()) ||
        !astGuaranteedToCorrespondToSIL)
      return false;

    const auto &SILOpts = Invocation.getSILOptions();
    const auto hasMultipleIGMs = SILOpts.hasMultipleIGMs();
    bool allSymbols = mode == FrontendOptions::TBDValidationMode::All;
    return MSF.is<SourceFile *>()
               ? validateTBD(MSF.get<SourceFile *>(), IRModule, hasMultipleIGMs,
                             allSymbols)
               : validateTBD(MSF.get<ModuleDecl *>(), IRModule, hasMultipleIGMs,
                             allSymbols);
  }
  }
}

static bool generateCode(CompilerInvocation &Invocation,
                         CompilerInstance &Instance, std::string OutputFilename,
                         llvm::Module *IRModule,
                         llvm::GlobalVariable *HashGlobal,
                         UnifiedStatsReporter *Stats);

static SerializationOptions
computeSerializationOptions(const CompilerInvocation &Invocation,
                            const SupplementaryOutputPaths &outs,
                            bool moduleIsPublic) {
  const FrontendOptions &opts = Invocation.getFrontendOptions();

  SerializationOptions serializationOpts;
  serializationOpts.OutputPath = outs.ModuleOutputPath.c_str();
  serializationOpts.DocOutputPath = outs.ModuleDocOutputPath.c_str();
  serializationOpts.GroupInfoPath = opts.GroupInfoPath.c_str();
  if (opts.SerializeBridgingHeader)
    serializationOpts.ImportedHeader = opts.ImplicitObjCHeaderPath;
  serializationOpts.ModuleLinkName = opts.ModuleLinkName;
  serializationOpts.ExtraClangOptions =
      Invocation.getClangImporterOptions().ExtraArgs;
  serializationOpts.EnableNestedTypeLookupTable =
      opts.EnableSerializationNestedTypeLookupTable;
  if (!Invocation.getIRGenOptions().ForceLoadSymbolName.empty())
    serializationOpts.AutolinkForceLoad = true;

  // Options contain information about the developer's computer,
  // so only serialize them if the module isn't going to be shipped to
  // the public.
  serializationOpts.SerializeOptionsForDebugging =
      !moduleIsPublic || opts.AlwaysSerializeDebuggingOptions;

  return serializationOpts;
}

static bool performCompileStepsPostSILGen(
    CompilerInstance &Instance, CompilerInvocation &Invocation,
    std::unique_ptr<SILModule> SM, bool astGuaranteedToCorrespondToSIL,
    ModuleOrSourceFile MSF, bool moduleIsPublic, int &ReturnValue,
    FrontendObserver *observer, UnifiedStatsReporter *Stats) {

  FrontendOptions opts = Invocation.getFrontendOptions();
  FrontendOptions::ActionType Action = opts.RequestedAction;
  ASTContext &Context = Instance.getASTContext();
  SILOptions &SILOpts = Invocation.getSILOptions();
  IRGenOptions &IRGenOpts = Invocation.getIRGenOptions();

  if (observer) {
    observer->performedSILGeneration(*SM);
  }
  if (Stats) {
    countStatsPostSILGen(*Stats, *SM);
  }

  if (auto r = emitSILAfterSILGen(Invocation, Instance, SM.get()))
    return *r;

  if (auto r = emitSIBAfterSILGen(Invocation, Instance, SM.get(), MSF))
    return *r;

  std::unique_ptr<llvm::raw_fd_ostream> OptRecordFile =
      createOptRecordFile(SILOpts.OptRecordFile, Instance.getDiags());
  if (OptRecordFile)
    SM->setOptRecordStream(llvm::make_unique<llvm::yaml::Output>(
                               *OptRecordFile, &Instance.getSourceMgr()),
                           std::move(OptRecordFile));

  if (performStableOptimizations(Invocation, SM.get(), observer))
    return true;

  {
    SharedTimer timer("SIL verification, pre-optimization");
    SM->verify();
  }

  // This is the action to be used to serialize SILModule.
  // It may be invoked multiple times, but it will perform
  // serialization only once. The serialization may either happen
  // after high-level optimizations or after all optimizations are
  // done, depending on the compiler setting.

  auto SerializeSILModuleAction = [&]() {
    const SupplementaryOutputPaths &outs =
        SM.get()->getPSPs().SupplementaryOutputs;

    if (outs.ModuleOutputPath.empty())
      return;

    SerializationOptions serializationOpts =
        computeSerializationOptions(Invocation, outs, moduleIsPublic);
    serialize(MSF, serializationOpts, SM.get());
  };

  // Set the serialization action, so that the SIL module
  // can be serialized at any moment, e.g. during the optimization pipeline.
  SM->setSerializeSILAction(SerializeSILModuleAction);

  performAndTimeSILOptimization(Invocation, SM.get());
  if (observer) {
    observer->performedSILOptimization(*SM);
  }
  if (Stats) {
    countStatsPostSILOpt(*Stats, *SM);
  }

  {
    SharedTimer timer("SIL verification, post-optimization");
    SM->verify();
  }

  gatherInstructionCounts(SM.get());
  setMSFPrivateDiscriminator(IRGenOpts, MSF);

  writeObjCHeader(Invocation, Instance.getMainModule(), moduleIsPublic,
                  SM.get()->getPSPs());

  if (auto r = emitSIBIFNeededAfterOptimizations(Invocation, SM.get(),
                                                 Instance.getASTContext(), MSF))
    return *r;

  if (auto r = emitModuleIfNeeded(SM.get(), Invocation, Instance, MSF))
    return *r;

  assert(Action >= FrontendOptions::ActionType::EmitSIL &&
         "All actions not requiring SILPasses must have been handled!");

  const std::string OutputFilename = SM.get()->getPSPs().OutputFilename;
  // We've been told to write canonical SIL, so write it now.
  if (Action == FrontendOptions::ActionType::EmitSIL) {
    return writeSIL(*SM, Instance.getMainModule(), opts.EmitVerboseSIL,
                    OutputFilename, opts.EmitSortedSIL);
  }

  assert(Action >= FrontendOptions::ActionType::Immediate &&
         "All actions not requiring IRGen must have been handled!");
  assert(Action != FrontendOptions::ActionType::REPL &&
         "REPL mode must be handled immediately after Instance->performSema()");

  // Check if we had any errors; if we did, don't proceed to IRGen.
  if (Context.hadError())
    return true;

  // Convert SIL to a lowered form suitable for IRGen.
  runSILLoweringPasses(*SM);

  // TODO: remove once the frontend understands what action it should perform
  IRGenOpts.OutputKind = getOutputKind(Action);
  if (Action == FrontendOptions::ActionType::Immediate)
    return setUpForAndRunImmediately(Invocation, Instance, std::move(SM), MSF,
                                     observer, ReturnValue);

  std::pair<std::unique_ptr<llvm::Module>, llvm::GlobalVariable *>
      IRModuleAndHashGlobal =
          generateIR(IRGenOpts, std::move(SM), OutputFilename, MSF);

  // Walk the AST for indexing after IR generation. Walking it before seems
  // to cause miscompilation issues.
  if (walkASTForIndexing(Invocation, Instance, MSF))
    return true;

  // Just because we had an AST error it doesn't mean we can't performLLVM.
  bool HadError = Instance.getASTContext().hadError();
  
  // If the AST Context has no errors but no IRModule is available,
  // parallelIRGen happened correctly, since parallel IRGen produces multiple
  // modules.
  if (!std::get<0>(IRModuleAndHashGlobal)) {
    return HadError;
  }

  if (validateTBDIfNeeded(Invocation, MSF, astGuaranteedToCorrespondToSIL,
                          *std::get<0>(IRModuleAndHashGlobal)))
    return true;

  return generateCode(Invocation, Instance, OutputFilename,
                      std::get<0>(IRModuleAndHashGlobal).get(),
                      std::get<1>(IRModuleAndHashGlobal), Stats) ||
         HadError;
}

static bool generateCode(CompilerInvocation &Invocation,
                         CompilerInstance &Instance, std::string OutputFilename,
                         llvm::Module *IRModule,
                         llvm::GlobalVariable *HashGlobal,
                         UnifiedStatsReporter *Stats) {
  std::unique_ptr<llvm::TargetMachine> TargetMachine = createTargetMachine(
      Invocation.getIRGenOptions(), Instance.getASTContext());
  version::Version EffectiveLanguageVersion =
      Instance.getASTContext().LangOpts.EffectiveLanguageVersion;

  // Free up some compiler resources now that we have an IRModule.
  Instance.freeSIL();
  // Need to keep this around for the next primary if > 1.
  // OTOH, don't bother to free it after the last one, even though it would OK
  // because that won't reduce peak heap usage, since the others have already
  // been compiled with it still around.
  if (Invocation.getFrontendOptions().InputsAndOutputs.primaryInputCount() < 2)
    Instance.freeContext();

  // Now that we have a single IR Module, hand it over to performLLVM.
  return performLLVM(Invocation.getIRGenOptions(), &Instance.getDiags(),
                     nullptr, HashGlobal, IRModule, TargetMachine.get(),
                     EffectiveLanguageVersion, OutputFilename, Stats);
}

static bool emitIndexData(SourceFile *PrimarySourceFile,
      const CompilerInvocation &Invocation,
      CompilerInstance &Instance) {
  const FrontendOptions &opts = Invocation.getFrontendOptions();
  assert(!opts.IndexStorePath.empty());
  // FIXME: provide index unit token(s) explicitly and only use output file
  // paths as a fallback.

  bool isDebugCompilation;
  switch (Invocation.getSILOptions().OptMode) {
    case OptimizationMode::NotSet:
    case OptimizationMode::NoOptimization:
      isDebugCompilation = true;
      break;
    case OptimizationMode::ForSpeed:
    case OptimizationMode::ForSize:
      isDebugCompilation = false;
      break;
  }

  if (PrimarySourceFile) {
    if (index::indexAndRecord(
            PrimarySourceFile, opts.InputsAndOutputs.getSingleOutputFilename(),
            opts.IndexStorePath, opts.IndexSystemModules, isDebugCompilation,
            Invocation.getTargetTriple(), *Instance.getDependencyTracker())) {
      return true;
    }
  } else {
    StringRef moduleToken = opts.InputsAndOutputs.getModuleOutputPath();
    if (moduleToken.empty())
      moduleToken = opts.InputsAndOutputs.getSingleOutputFilename();

    if (index::indexAndRecord(
            Instance.getMainModule(),
            opts.InputsAndOutputs.copyOutputFilenames(), moduleToken,
            opts.IndexStorePath, opts.IndexSystemModules, isDebugCompilation,
            Invocation.getTargetTriple(), *Instance.getDependencyTracker())) {
      return true;
    }
  }

  return false;
}

/// Returns true if an error occurred.
static bool dumpAPI(ModuleDecl *Mod, StringRef OutDir) {
  using namespace llvm::sys;

  auto getOutPath = [&](SourceFile *SF) -> std::string {
    SmallString<256> Path = OutDir;
    StringRef Filename = SF->getFilename();
    path::append(Path, path::filename(Filename));
    return Path.str();
  };

  std::unordered_set<std::string> Filenames;

  auto dumpFile = [&](SourceFile *SF) -> bool {
    SmallString<512> TempBuf;
    llvm::raw_svector_ostream TempOS(TempBuf);

    PrintOptions PO = PrintOptions::printInterface();
    PO.PrintOriginalSourceText = true;
    PO.Indent = 2;
    PO.PrintAccess = false;
    PO.SkipUnderscoredStdlibProtocols = true;
    SF->print(TempOS, PO);
    if (TempOS.str().trim().empty())
      return false; // nothing to show.

    std::string OutPath = getOutPath(SF);
    bool WasInserted = Filenames.insert(OutPath).second;
    if (!WasInserted) {
      llvm::errs() << "multiple source files ended up with the same dump API "
                      "filename to write to: " << OutPath << '\n';
      return true;
    }

    std::error_code EC;
    llvm::raw_fd_ostream OS(OutPath, EC, fs::OpenFlags::F_RW);
    if (EC) {
      llvm::errs() << "error opening file '" << OutPath << "': "
                   << EC.message() << '\n';
      return true;
    }

    OS << TempOS.str();
    return false;
  };

  std::error_code EC = fs::create_directories(OutDir);
  if (EC) {
    llvm::errs() << "error creating directory '" << OutDir << "': "
                 << EC.message() << '\n';
    return true;
  }

  for (auto *FU : Mod->getFiles()) {
    if (auto *SF = dyn_cast<SourceFile>(FU))
      if (dumpFile(SF))
        return true;
  }

  return false;
}

static StringRef
silOptModeArgStr(OptimizationMode mode) {
  switch (mode) {
 case OptimizationMode::ForSpeed:
   return "O";
 case OptimizationMode::ForSize:
   return "Osize";
 default:
   return "Onone";
  }
}

static std::unique_ptr<UnifiedStatsReporter>
computeStatsReporter(const CompilerInvocation &Invocation, SourceManager &SM) {
  const std::string &StatsOutputDir =
      Invocation.getFrontendOptions().StatsOutputDir;
  std::unique_ptr<UnifiedStatsReporter> StatsReporter;
  if (StatsOutputDir.empty())
    return std::unique_ptr<UnifiedStatsReporter>();

  auto &FEOpts = Invocation.getFrontendOptions();
  auto &LangOpts = Invocation.getLangOptions();
  auto &SILOpts = Invocation.getSILOptions();
  std::string InputName =
      FEOpts.InputsAndOutputs.getStatsFileMangledInputName();
  StringRef OptType = silOptModeArgStr(SILOpts.OptMode);
  StringRef OutFile =
      FEOpts.InputsAndOutputs.lastInputProducingOutput().outputFilename();
  StringRef OutputType = llvm::sys::path::extension(OutFile);
  std::string TripleName = LangOpts.Target.normalize();
  auto Trace = Invocation.getFrontendOptions().TraceStats;
  return llvm::make_unique<UnifiedStatsReporter>(
      "swift-frontend", FEOpts.ModuleName, InputName, TripleName, OutputType,
      OptType, StatsOutputDir, &SM, Trace);
}

static bool isDependencyTrackerNeeded(const CompilerInvocation &Invocation) {
  return Invocation.getFrontendOptions().hasDependencyTrackerPath();
}

static Optional<int> configureInvocation(
    CompilerInvocation &Invocation, DiagnosticEngine &Diags,
    FrontendObserver *observer, ArrayRef<const char *> Args, const char *Argv0,
    void *MainAddr,
    llvm::function_ref<int(int retValue)> finishDiagProcessing) {
  if (Args.empty()) {
    Diags.diagnose(SourceLoc(), diag::error_no_frontend_args);
    return finishDiagProcessing(1);
  }

  std::string MainExecutablePath = llvm::sys::fs::getMainExecutable(Argv0,
                                                                    MainAddr);
  Invocation.setMainExecutablePath(MainExecutablePath);

  SmallString<128> workingDirectory;
  llvm::sys::fs::current_path(workingDirectory);

  // Parse arguments.
  if (Invocation.parseArgs(Args, Diags, workingDirectory)) {
    return finishDiagProcessing(1);
  }

  // Setting DWARF Version depend on platform
  IRGenOptions &IRGenOpts = Invocation.getIRGenOptions();
  IRGenOpts.DWARFVersion = swift::DWARFVersion;

  // The compiler invocation is now fully configured; notify our observer.
  if (observer) {
    observer->parsedArgs(Invocation);
  }

  if (Invocation.getFrontendOptions().PrintHelp ||
      Invocation.getFrontendOptions().PrintHelpHidden) {
    unsigned IncludedFlagsBitmask = options::FrontendOption;
    unsigned ExcludedFlagsBitmask =
        Invocation.getFrontendOptions().PrintHelpHidden ? 0
                                                        : llvm::opt::HelpHidden;
    std::unique_ptr<llvm::opt::OptTable> Options(createSwiftOptTable());
    Options->PrintHelp(llvm::outs(), displayName(MainExecutablePath).c_str(),
                       "Swift frontend", IncludedFlagsBitmask,
                       ExcludedFlagsBitmask);
    return finishDiagProcessing(0);
  }
  if (Invocation.getFrontendOptions().RequestedAction ==
      FrontendOptions::ActionType::NoneAction) {
    Diags.diagnose(SourceLoc(), diag::error_missing_frontend_action);
    return finishDiagProcessing(1);
  }
  return None;
}

/// \return a value iff failed

static std::tuple<Optional<int>, std::unique_ptr<DiagnosticConsumer>,
                  std::unique_ptr<DiagnosticConsumer>>
configureCompilerInstance(
    CompilerInstance *Instance, CompilerInvocation &Invocation,
    PrintingDiagnosticConsumer &PDC,
    llvm::function_ref<int(int retValue)> finishDiagProcessing,
    UnifiedStatsReporter *StatsReporter, DependencyTracker &depTracker) {

  // Because the serialized diagnostics consumer is initialized here,
  // diagnostics emitted within CompilerInvocation::parseArgs, are never
  // serialized. This is a non-issue because, in nearly all cases, frontend
  // arguments are generated by the driver, not directly by a user. The driver
  // is responsible for emitting diagnostics for its own errors. See SR-2683
  // for details.
  std::unique_ptr<DiagnosticConsumer> SerializedConsumer;
  {
    const std::string &SerializedDiagnosticsPath =
        Invocation.getFrontendOptions()
            .InputsAndOutputs.getSerializedDiagnosticsPath();
    if (!SerializedDiagnosticsPath.empty()) {
      SerializedConsumer.reset(
          serialized_diagnostics::createConsumer(SerializedDiagnosticsPath));
      Instance->addDiagnosticConsumer(SerializedConsumer.get());
    }
  }

  std::unique_ptr<DiagnosticConsumer> FixitsConsumer;
  {
    const std::string &FixitsOutputPath =
        Invocation.getFrontendOptions().FixitsOutputPath;
    if (!FixitsOutputPath.empty()) {
      FixitsConsumer.reset(new JSONFixitWriter(
          FixitsOutputPath, Invocation.getDiagnosticOptions()));
      Instance->addDiagnosticConsumer(FixitsConsumer.get());
    }
  }

  if (Invocation.getDiagnosticOptions().UseColor)
    PDC.forceColors();

  if (Invocation.getFrontendOptions().DebugTimeCompilation)
    SharedTimer::enableCompilationTimers();

  if (Invocation.getFrontendOptions().PrintStats) {
    llvm::EnableStatistics();
  }

  const DiagnosticOptions &diagOpts = Invocation.getDiagnosticOptions();
  if (diagOpts.VerifyMode != DiagnosticOptions::NoVerify) {
    enableDiagnosticVerifier(Instance->getSourceMgr());
  }

  if (isDependencyTrackerNeeded(Invocation))
    Instance->setDependencyTracker(&depTracker);

  if (Instance->setup(Invocation)) {
    return std::make_tuple(finishDiagProcessing(1),
                           std::move(SerializedConsumer),
                           std::move(FixitsConsumer));
  }

  if (StatsReporter) {
    // Install stats-reporter somewhere visible for subsystems that
    // need to bump counters as they work, rather than measure
    // accumulated work on completion (mostly: TypeChecker).
    Instance->getASTContext().Stats = StatsReporter;
  }
  return std::make_tuple(None, std::move(SerializedConsumer),
                         std::move(FixitsConsumer));
}

static bool verifyAndDiagnose(CompilerInstance *Instance,
                              const CompilerInvocation &Invocation) {
  const DiagnosticOptions &diagOpts = Invocation.getDiagnosticOptions();
  bool HadError = verifyDiagnostics(
      Instance->getSourceMgr(), Instance->getInputBufferIDs(),
      diagOpts.VerifyMode == DiagnosticOptions::VerifyAndApplyFixes,
      diagOpts.VerifyIgnoreUnknown);

  DiagnosticEngine &diags = Instance->getDiags();
  if (diags.hasFatalErrorOccurred() &&
      !Invocation.getDiagnosticOptions().ShowDiagnosticsAfterFatalError) {
    diags.resetHadAnyError();
    diags.diagnose(SourceLoc(), diag::verify_encountered_fatal);
    return true;
  }
  return HadError;
}

static int handleResultOfCompilation(
    bool HadError, CompilerInstance *Instance,
    const CompilerInvocation &Invocation, int ReturnValue,
    UnifiedStatsReporter *StatsReporter,
    llvm::function_ref<int(int retValue)> finishDiagProcessing) {
  if (!HadError) {
    Mangle::printManglingStats();
  }

  if (!HadError && !Invocation.getFrontendOptions().DumpAPIPath.empty()) {
    HadError = dumpAPI(Instance->getMainModule(),
                       Invocation.getFrontendOptions().DumpAPIPath);
  }
  const DiagnosticOptions &diagOpts = Invocation.getDiagnosticOptions();
  if (diagOpts.VerifyMode != DiagnosticOptions::NoVerify)
    HadError = verifyAndDiagnose(Instance, Invocation);

  auto r = finishDiagProcessing(HadError ? 1 : ReturnValue);
  if (StatsReporter)
    StatsReporter->noteCurrentProcessExitStatus(r);
  return r;
}

int swift::performFrontend(ArrayRef<const char *> Args, const char *Argv0,
                           void *MainAddr, FrontendObserver *observer) {
  llvm::InitializeAllTargets();
  llvm::InitializeAllTargetMCs();
  llvm::InitializeAllAsmPrinters();
  llvm::InitializeAllAsmParsers();

  PrintingDiagnosticConsumer PDC;

  // Hopefully we won't trigger any LLVM-level fatal errors, but if we do try
  // to route them through our usual textual diagnostics before crashing.
  //
  // Unfortunately it's not really safe to do anything else, since very
  // low-level operations in LLVM can trigger fatal errors.
  auto diagnoseFatalError = [&PDC](const std::string &reason,
                                   bool shouldCrash) {
    static const std::string *recursiveFatalError = nullptr;
    if (recursiveFatalError) {
      // Report the /original/ error through LLVM's default handler, not
      // whatever we encountered.
      llvm::remove_fatal_error_handler();
      llvm::report_fatal_error(*recursiveFatalError, shouldCrash);
    }
    recursiveFatalError = &reason;

    SourceManager dummyMgr;

    PDC.handleDiagnostic(dummyMgr, SourceLoc(), DiagnosticKind::Error,
                         "fatal error encountered during compilation; please "
                         "file a bug report with your project and the crash "
                         "log",
                         {}, DiagnosticInfo());
    PDC.handleDiagnostic(dummyMgr, SourceLoc(), DiagnosticKind::Note, reason,
                         {}, DiagnosticInfo());
    if (shouldCrash)
      abort();
  };
  llvm::ScopedFatalErrorHandler handler(
      [](void *rawCallback, const std::string &reason, bool shouldCrash) {
        auto *callback =
            static_cast<decltype(&diagnoseFatalError)>(rawCallback);
        (*callback)(reason, shouldCrash);
      },
      &diagnoseFatalError);

  std::unique_ptr<CompilerInstance> Instance =
      llvm::make_unique<CompilerInstance>();
  Instance->addDiagnosticConsumer(&PDC);

  struct FinishDiagProcessingCheckRAII {
    bool CalledFinishDiagProcessing = false;
    ~FinishDiagProcessingCheckRAII() {
      assert(CalledFinishDiagProcessing &&
             "returned from the function "
             "without calling finishDiagProcessing");
    }
  } FinishDiagProcessingCheckRAII;

  auto finishDiagProcessing = [&](int retValue) -> int {
    FinishDiagProcessingCheckRAII.CalledFinishDiagProcessing = true;
    bool err = Instance->getDiags().finishProcessing();
    return retValue ? retValue : err;
  };

  CompilerInvocation Invocation;

  if (Optional<int> retVal =
          configureInvocation(Invocation, Instance->getDiags(), observer, Args,
                              Argv0, MainAddr, finishDiagProcessing)) {
    return *retVal;
  }

  std::unique_ptr<UnifiedStatsReporter> StatsReporter =
      computeStatsReporter(Invocation, Instance->getSourceMgr());

  DependencyTracker depTracker;

  std::tuple<Optional<int>, std::unique_ptr<DiagnosticConsumer>,
             std::unique_ptr<DiagnosticConsumer>>
      resultSerializedConsumerFixitsConsumer =
          configureCompilerInstance(Instance.get(), Invocation, PDC,
                                    finishDiagProcessing, StatsReporter.get(),
                                    depTracker);
  if (auto retVal = std::get<0>(resultSerializedConsumerFixitsConsumer)) {
    return *retVal;
  }

  // The compiler instance has been configured; notify our observer.
  if (observer) {
    observer->configuredCompiler(*Instance);
  }

  int ReturnValue = 0;
  bool HadError = performCompile(*Instance, Invocation, Args, ReturnValue,
                                 observer, StatsReporter.get());

  return handleResultOfCompilation(HadError, Instance.get(), Invocation,
                                   ReturnValue, StatsReporter.get(),
                                   finishDiagProcessing);
}

void FrontendObserver::parsedArgs(CompilerInvocation &invocation) {}
void FrontendObserver::configuredCompiler(CompilerInstance &instance) {}
void FrontendObserver::performedSemanticAnalysis(CompilerInstance &instance) {}
void FrontendObserver::performedSILGeneration(SILModule &module) {}
void FrontendObserver::performedSILDiagnostics(SILModule &module) {}
void FrontendObserver::performedSILOptimization(SILModule &module) {}
void FrontendObserver::aboutToRunImmediately(CompilerInstance &instance) {}
