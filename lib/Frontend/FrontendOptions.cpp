//===--- FrontendOptions.cpp ----------------------------------------------===//
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

#include "swift/Frontend/FrontendOptions.h"

#include "swift/AST/DiagnosticsFrontend.h"
#include "swift/Option/Options.h"
#include "swift/Parse/Lexer.h"
#include "swift/Strings.h"
#include "llvm/Option/Arg.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Option/Option.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/LineIterator.h"
#include "llvm/Support/Path.h"

using namespace swift;
using namespace llvm::opt;

bool FrontendInputs::shouldTreatAsLLVM() const {
  if (hasUniqueInputFilename()) {
    StringRef Input(getFilenameOfFirstInput());
    return llvm::sys::path::extension(Input).endswith(LLVM_BC_EXTENSION) ||
           llvm::sys::path::extension(Input).endswith(LLVM_IR_EXTENSION);
  }
  return false;
}

bool FrontendInputs::shouldTreatAsSIL() const {
  if (hasUniqueInputFilename()) {
    // If we have exactly one input filename, and its extension is "sil",
    // treat the input as SIL.
    StringRef Input(getFilenameOfFirstInput());
    return llvm::sys::path::extension(Input).endswith(SIL_EXTENSION);
  }
  StringRef Input = primaryInputFilenameIfAny();
  if (!Input.empty()) {
    // If we have a primary input and it's a filename with extension "sil",
    // treat the input as SIL.
    return llvm::sys::path::extension(Input).endswith(SIL_EXTENSION);
  }
  return false;
}

bool FrontendInputs::verifyInputs(DiagnosticEngine &Diags, bool TreatAsSIL,
                                  bool isREPLRequested,
                                  bool isNoneRequested) const {
  if (isREPLRequested) {
    if (hasInputFilenames()) {
      Diags.diagnose(SourceLoc(), diag::error_repl_requires_no_input_files);
      return true;
    }
  } else if (TreatAsSIL && havePrimaryInputs()) {
    // If we have the SIL as our primary input, we can waive the one file
    // requirement as long as all the other inputs are SIBs.
    for (unsigned i = 0, e = inputFilenameCount(); i != e; ++i) {
      if (i == getPrimaryInput()->Index)
        continue;

      StringRef File(getInputFilenames()[i]);
      if (!llvm::sys::path::extension(File).endswith(SIB_EXTENSION)) {
        Diags.diagnose(SourceLoc(),
                       diag::error_mode_requires_one_sil_multi_sib);
        return true;
      }
    }
  } else if (TreatAsSIL) {
    if (!hasUniqueInputFilename()) {
      Diags.diagnose(SourceLoc(), diag::error_mode_requires_one_input_file);
      return true;
    }
  } else if (!isNoneRequested) {
    if (!hasInputFilenames()) {
      Diags.diagnose(SourceLoc(), diag::error_mode_requires_an_input_file);
      return true;
    }
  }
  return false;
}

void FrontendInputs::transformInputFilenames(
    const llvm::function_ref<std::string(std::string)> &fn) {
  for (auto &InputFile : InputFilenames) {
    InputFile = fn(InputFile);
  }
}

void FrontendInputs::setInputFilenamesAndPrimaryInput(
    DiagnosticEngine &Diags, llvm::opt::ArgList &Args) {
  if (const Arg *filelistPath = Args.getLastArg(options::OPT_filelist)) {
    readInputFileList(Diags, Args, filelistPath);
    return;
  }
  for (const Arg *A :
       Args.filtered(options::OPT_INPUT, options::OPT_primary_file)) {
    if (A->getOption().matches(options::OPT_INPUT)) {
      addInputFilename(A->getValue());
    } else if (A->getOption().matches(options::OPT_primary_file)) {
      setPrimaryInput(SelectedInput(inputFilenameCount()));
      addInputFilename(A->getValue());
    } else {
      llvm_unreachable("Unknown input-related argument!");
    }
  }
}

/// Try to read an input file list file.
///
/// Returns false on error.
void FrontendInputs::readInputFileList(DiagnosticEngine &diags,
                                       llvm::opt::ArgList &Args,
                                       const llvm::opt::Arg *filelistPath) {
  llvm::ErrorOr<std::unique_ptr<llvm::MemoryBuffer>> buffer =
      llvm::MemoryBuffer::getFile(filelistPath->getValue());
  if (!buffer) {
    diags.diagnose(SourceLoc(), diag::cannot_open_file,
                   filelistPath->getValue(), buffer.getError().message());
    return;
  }

  const Arg *primaryFileArg = Args.getLastArg(options::OPT_primary_file);
  unsigned primaryFileIndex = 0;

  bool foundPrimaryFile = false;

  for (StringRef line : make_range(llvm::line_iterator(*buffer.get()), {})) {
    addInputFilename(line);

    if (foundPrimaryFile || primaryFileArg == nullptr)
      continue;
    if (line == primaryFileArg->getValue())
      foundPrimaryFile = true;
    else
      ++primaryFileIndex;
  }

  if (primaryFileArg && !foundPrimaryFile) {
    diags.diagnose(SourceLoc(), diag::error_primary_file_not_found,
                   primaryFileArg->getValue(), filelistPath->getValue());
    return;
  }

  if (primaryFileArg)
    setPrimaryInput(SelectedInput(primaryFileIndex));
  assert(!Args.hasArg(options::OPT_INPUT) && "mixing -filelist with inputs");
}

bool FrontendOptions::actionHasOutput() const {
  switch (RequestedAction) {
  case NoneAction:
  case Parse:
  case Typecheck:
  case DumpParse:
  case DumpAST:
  case EmitSyntax:
  case DumpInterfaceHash:
  case PrintAST:
  case DumpScopeMaps:
  case DumpTypeRefinementContexts:
    return false;
  case EmitPCH:
  case EmitSILGen:
  case EmitSIL:
  case EmitSIBGen:
  case EmitSIB:
  case EmitModuleOnly:
  case MergeModules:
    return true;
  case Immediate:
  case REPL:
    return false;
  case EmitAssembly:
  case EmitIR:
  case EmitBC:
  case EmitObject:
  case EmitImportedModules:
    return true;
  }
  llvm_unreachable("Unknown ActionType");
}

bool FrontendOptions::actionIsImmediate() const {
  switch (RequestedAction) {
  case NoneAction:
  case Parse:
  case Typecheck:
  case DumpParse:
  case DumpAST:
  case EmitSyntax:
  case DumpInterfaceHash:
  case PrintAST:
  case DumpScopeMaps:
  case DumpTypeRefinementContexts:
  case EmitPCH:
  case EmitSILGen:
  case EmitSIL:
  case EmitSIBGen:
  case EmitSIB:
  case EmitModuleOnly:
  case MergeModules:
    return false;
  case Immediate:
  case REPL:
    return true;
  case EmitAssembly:
  case EmitIR:
  case EmitBC:
  case EmitObject:
  case EmitImportedModules:
    return false;
  }
  llvm_unreachable("Unknown ActionType");
}

void FrontendOptions::forAllOutputPaths(
    std::function<void(const std::string &)> fn) const {
  if (RequestedAction != FrontendOptions::EmitModuleOnly &&
      RequestedAction != FrontendOptions::MergeModules) {
    for (const std::string &OutputFileName : OutputFilenames) {
      fn(OutputFileName);
    }
  }
  const std::string *outputs[] = {
    &ModuleOutputPath,
    &ModuleDocOutputPath,
    &ObjCHeaderOutputPath
  };
  for (const std::string *next : outputs) {
    if (!next->empty())
      fn(*next);
  }
}

StringRef FrontendOptions::originalPath() const {
  if (hasNamedOutputFile())
    // Put the serialized diagnostics file next to the output file.
    return getSingleOutputFilename();

  StringRef fn = Inputs.primaryInputFilenameIfAny();
  // If we have a primary input, so use that as the basis for the name of the
  // serialized diagnostics file, otherwise fall back on the
  // module name.
  return !fn.empty() ? llvm::sys::path::filename(fn) : StringRef(ModuleName);
}


bool FrontendOptions::isOutputFileDirectory() const {
  return hasNamedOutputFile() &&
         llvm::sys::fs::is_directory(getSingleOutputFilename());
}

const char *FrontendOptions::computeSuffix() {
  switch (RequestedAction) {
    case NoneAction:
      return nullptr;
      
    case Parse:
    case Typecheck:
    case DumpParse:
    case DumpInterfaceHash:
    case DumpAST:
    case EmitSyntax:
    case PrintAST:
    case DumpScopeMaps:
    case DumpTypeRefinementContexts:
      // Textual modes.
      return nullptr;
      
    case EmitPCH:
      return PCH_EXTENSION;
      
    case EmitSILGen:
    case EmitSIL:
      return SIL_EXTENSION;
      
    case EmitSIBGen:
    case EmitSIB:
      return SIB_EXTENSION;
      
    case MergeModules:
    case EmitModuleOnly:
      return SERIALIZED_MODULE_EXTENSION;
      
    case Immediate:
    case REPL:
      // These modes have no frontend-generated output.
      return nullptr;
      
    case EmitAssembly:
      return "s";
      
    case EmitIR:
      return "ll";
      
    case EmitBC:
      return "bc";
      
    case EmitObject:
      return "o";
      
    case EmitImportedModules:
      return "importedmodules";
  }
}

bool FrontendOptions::canEmitDependencies() const {
  if (DependenciesFilePath.empty())
    return true;
  switch (RequestedAction) {
    case NoneAction:
    case DumpParse:
    case DumpInterfaceHash:
    case DumpAST:
    case EmitSyntax:
    case PrintAST:
    case DumpScopeMaps:
    case DumpTypeRefinementContexts:
    case Immediate:
    case REPL:
      return false;
    case Parse:
    case Typecheck:
    case MergeModules:
    case EmitModuleOnly:
    case EmitPCH:
    case EmitSILGen:
    case EmitSIL:
    case EmitSIBGen:
    case EmitSIB:
    case EmitIR:
    case EmitBC:
    case EmitAssembly:
    case EmitObject:
    case EmitImportedModules:
      return true;
  }
}

bool FrontendOptions::canEmitHeader() const {
  if (ObjCHeaderOutputPath.empty())
    return true;
  switch (RequestedAction) {
    case NoneAction:
    case DumpParse:
    case DumpInterfaceHash:
    case DumpAST:
    case EmitSyntax:
    case PrintAST:
    case EmitPCH:
    case DumpScopeMaps:
    case DumpTypeRefinementContexts:
    case Immediate:
    case REPL:
      return false;
    case Parse:
    case Typecheck:
    case MergeModules:
    case EmitModuleOnly:
    case EmitSILGen:
    case EmitSIL:
    case EmitSIBGen:
    case EmitSIB:
    case EmitIR:
    case EmitBC:
    case EmitAssembly:
    case EmitObject:
    case EmitImportedModules:
      return true;
  }
}

bool FrontendOptions::canEmitLoadedModuleTrace() const {
  if (LoadedModuleTracePath.empty())
    return true;
  switch (RequestedAction) {
    case NoneAction:
    case Parse:
    case DumpParse:
    case DumpInterfaceHash:
    case DumpAST:
    case EmitSyntax:
    case PrintAST:
    case DumpScopeMaps:
    case DumpTypeRefinementContexts:
    case Immediate:
    case REPL:
      return false;
    case Typecheck:
    case MergeModules:
    case EmitModuleOnly:
    case EmitPCH:
    case EmitSILGen:
    case EmitSIL:
    case EmitSIBGen:
    case EmitSIB:
    case EmitIR:
    case EmitBC:
    case EmitAssembly:
    case EmitObject:
    case EmitImportedModules:
      return true;
  }
}

bool FrontendOptions::canEmitModule() const {
  if (ModuleOutputPath.empty() && ModuleDocOutputPath.empty())
    return true;
  switch (RequestedAction) {
    case NoneAction:
    case Parse:
    case Typecheck:
    case DumpParse:
    case DumpInterfaceHash:
    case DumpAST:
    case EmitSyntax:
    case PrintAST:
    case EmitPCH:
    case DumpScopeMaps:
    case DumpTypeRefinementContexts:
    case EmitSILGen:
    case Immediate:
    case REPL:
      return false;
    case MergeModules:
    case EmitModuleOnly:
    case EmitSIL:
    case EmitSIBGen:
    case EmitSIB:
    case EmitIR:
    case EmitBC:
    case EmitAssembly:
    case EmitObject:
    case EmitImportedModules:
      return true;
  }
}

bool FrontendOptions::actionProducesOutputFromFrontend() const {
  switch (RequestedAction) {
    case NoneAction:
    case EmitPCH:
    case EmitSIBGen:
    case EmitSIB:
    case MergeModules:
    case EmitModuleOnly:
    case EmitBC:
    case EmitObject:
    case Parse:
    case Typecheck:
    case DumpParse:
    case DumpInterfaceHash:
    case DumpAST:
    case EmitSyntax:
    case PrintAST:
    case DumpScopeMaps:
    case DumpTypeRefinementContexts:
    case EmitImportedModules:
    case EmitSILGen:
    case EmitSIL:
    case EmitAssembly:
    case EmitIR:
      return true;
      
    case Immediate:
    case REPL:
      // These modes have no frontend-generated output.
      return false;
  }
}

bool FrontendOptions::actionOutputsToStdout() const {
  switch (RequestedAction) {
    case NoneAction:
    case EmitPCH:
    case EmitSIBGen:
    case EmitSIB:
    case MergeModules:
    case EmitModuleOnly:
    case EmitBC:
    case EmitObject:
    case Immediate:
    case REPL:
      return false;
      
    case Parse:
    case Typecheck:
    case DumpParse:
    case DumpInterfaceHash:
    case DumpAST:
    case EmitSyntax:
    case PrintAST:
    case DumpScopeMaps:
    case DumpTypeRefinementContexts:
    case EmitImportedModules:
    case EmitSILGen:
    case EmitSIL:
    case EmitAssembly:
    case EmitIR:
      return true;
  }
}

