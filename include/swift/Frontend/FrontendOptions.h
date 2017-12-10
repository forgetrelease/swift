//===--- FrontendOptions.h --------------------------------------*- C++ -*-===//
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

#ifndef SWIFT_FRONTEND_FRONTENDOPTIONS_H
#define SWIFT_FRONTEND_FRONTENDOPTIONS_H

#include "swift/AST/Module.h"
#include "llvm/ADT/Hashing.h"
#include "llvm/ADT/MapVector.h"

#include <string>
#include <vector>

namespace llvm {
  class MemoryBuffer;
}

namespace swift {
  
  
  struct OutputPaths {
    /// The specified output file (.o).
    std::string OutputFilename;
    
    /// The path to which we should emit an Objective-C header for the module.
    std::string ObjCHeaderOutputPath;
    
    /// The path to which we should emit a serialized module.
    std::string ModuleOutputPath;
    
    /// The path to which we should emit a module documentation file.
    std::string ModuleDocOutputPath;
    
    /// The path to which we should output a Make-style dependencies file.
    std::string DependenciesFilePath;
    
    /// The path to which we should output a Swift reference dependencies file.
    std::string ReferenceDependenciesFilePath;
    
    /// Path to a file which should contain serialized diagnostics for this
    /// frontend invocation.
    std::string SerializedDiagnosticsPath;
    
    /// The path to which we should output a loaded module trace file.
    std::string LoadedModuleTracePath;
    
    /// The path to which we should output a TBD file.
    std::string TBDPath;
    
    OutputPaths(unsigned i,
                Optional<std::vector<std::string>> &objCHeaderOutputs,
                Optional<std::vector<std::string>> &moduleOutput,
                Optional<std::vector<std::string>> &moduleDocOutputs,
                Optional<std::vector<std::string>> &dependenciesFiles,
                Optional<std::vector<std::string>> &referenceDependenciesFiles,
                Optional<std::vector<std::string>> &serializedDiagnostics,
                Optional<std::vector<std::string>> &loadedModuleTrace,
                Optional<std::vector<std::string>> &TBDs
                ) :
     ObjCHeaderOutputPath(ith(objCHeaderOutputs, i)),
     ModuleOutputPath(ith(moduleOutput, i)),
     ModuleDocOutputPath(ith(moduleDocOutputs, i)),
     DependenciesFilePath(ith(dependenciesFiles, i)),
     ReferenceDependenciesFilePath(ith(referenceDependenciesFiles, i)),
     SerializedDiagnosticsPath(ith(serializedDiagnostics, i)),
     LoadedModuleTracePath(ith(loadedModuleTrace, i)),
     TBDPath(ith(TBDs, i))
        {  }
    
    OutputPaths() = default;
    
  private:
    static std::string ith(Optional<std::vector<std::string>> &names, unsigned i) {
      return !names ? "" : (*names)[i];
    }
  };
  

enum class InputFileKind {
  IFK_None,
  IFK_Swift,
  IFK_Swift_Library,
  IFK_Swift_REPL,
  IFK_SIL,
  IFK_LLVM_IR
};

// Inputs may include buffers that override contents, and eventually should
// always include a buffer.
class InputFile {
  std::string Filename;
  bool IsPrimary;
  /// Null if the contents are not overridden.
  llvm::MemoryBuffer *Buffer;
  OutputPaths Outputs;

public:
  /// Does not take ownership of \p buffer. Does take ownership of (copy) a
  /// string.
  InputFile(StringRef name, bool isPrimary,
            llvm::MemoryBuffer *buffer = nullptr)
      : Filename(name), IsPrimary(isPrimary), Buffer(buffer) {
    assert(!name.empty() && "Empty strings signify no inputs in other places");
  }

  bool getIsPrimary() const { return IsPrimary; }
  llvm::MemoryBuffer *getBuffer() const { return Buffer; }
  StringRef getFile() const { return Filename; }
  const OutputPaths &outputs() const { return Outputs; }
  OutputPaths &malleableOutputs() { return Outputs; }
};


/// Information about all the inputs to the frontend.
class FrontendInputsAndOutputs {
  friend class ArgsToFrontendInputsConverter;

  std::vector<InputFile> AllFiles;
  typedef llvm::MapVector<StringRef, unsigned> InputFileMap;
  InputFileMap PrimaryInputs;

public:
  FrontendInputsAndOutputs() = default;

  FrontendInputsAndOutputs(const FrontendInputsAndOutputs &other) {
    for (InputFile input : other.getAllFiles())
      addInput(input);
  }
  FrontendInputsAndOutputs(FrontendInputsAndOutputs &&other) {
    AllFiles = std::move(other.AllFiles);
    PrimaryInputs = std::move(other.PrimaryInputs);
  }
  FrontendInputsAndOutputs &operator=(const FrontendInputsAndOutputs &other) {
    clearInputs();
    for (InputFile input : other.getAllFiles())
      addInput(input);
    return *this;
  }
  
  // Readers:
  // FIXME: Can these be const to ensure PrimaryInputs invarients are preserved?
  ArrayRef<InputFile> getAllFiles() const { return AllFiles; }
  std::vector<InputFile> &getAllFilesMalleably()  { return AllFiles; }
  std::vector<InputFile*> getAllFilePointersMalleable() {
    std::vector<InputFile*> pointers;
    for (InputFile &input: AllFiles) {
      pointers.push_back(&input);
    }
    return pointers;
  }
  // FIXME: Can I use an iterator instead of making a new collection?
  
  
  
  
//  std::vector<const InputFile &> getAllPrimaries() const {
//    std::vector<const InputFile &> primaries;
//    forEachPrimary([&] (InputFile& input) -> void {
//      primaries.push_back(input);
//    });
//    return primaries;
//  }
  std::vector<InputFile*> getAllPrimariesMalleably() {
    std::vector<InputFile*> primaries;
    forEachPrimaryMalleably([&] (InputFile& input) -> void {
      primaries.push_back(&input);
    });
    return primaries;
  }
  
  void forEachPrimary(llvm::function_ref<void(const InputFile& input)> fn) const {
    for (auto p: PrimaryInputs)
      fn(getAllFiles()[p.second]);
  }
  
  void forEachPrimaryMalleably(llvm::function_ref<void(InputFile& input)> fn) {
    for (auto p: PrimaryInputs)
      fn(getAllFilesMalleably()[p.second]);
  }
  
  StringRef lastOutputFilename() {
    // FIXME use reverse iterator?
    for (auto i = AllFiles.size(); ; ) {
      if (!AllFiles[i].outputs().OutputFilename.empty())
        return AllFiles[i].outputs().OutputFilename;
      if (i == 0) break;
    }
    return StringRef();
  }
  
  // FIXME: iterator?
  std::vector<std::string> getInputFilenames() const {
    std::vector<std::string> filenames;
    for (auto &input : getAllFiles()) {
      assert(!input.getFile().empty());
      filenames.push_back(input.getFile());
    }
    return filenames;
  }

  unsigned inputCount() const { return getAllFiles().size(); }

  bool hasInputs() const { return !AllFiles.empty(); }

  bool hasUniqueInput() const { return inputCount() == 1; }

  const StringRef getFilenameOfFirstInput() const {
    assert(hasInputs());
    const InputFile &inp = getAllFiles()[0];
    StringRef f = inp.getFile();
    assert(!f.empty());
    return f;
  }

  bool isReadingFromStdin() const {
    return hasUniqueInput() && getFilenameOfFirstInput() == "-";
  }

  // If we have exactly one input filename, and its extension is "bc" or "ll",
  // treat the input as LLVM_IR.
  bool shouldTreatAsLLVM() const;

  // Primary input readers

private:
  
  bool doAllNonPrimariesEndWithSIB() const;

public:
  void assertMustNotBeMoreThanOnePrimaryInput() const {
    assert(primaryInputCount() < 2 &&
           "have not implemented >1 primary input yet");
  }
  
  unsigned primaryInputCount() const { return PrimaryInputs.size(); }

  // Primary count readers:

  bool hasUniquePrimaryInput() const { return primaryInputCount() == 1; }

  bool hasPrimaries() const { return primaryInputCount() > 0; }

  bool isWholeModule() const { return !hasPrimaries(); }
  
//  void forEachPrimaryOrEmpty(llvm::function_ref<void(StringRef)> fn) const{
//    if (!hasPrimaries())
//      fn("");
//    else
//      for (const auto &p: PrimaryInputs)
//        fn(p.first);
//  }
  
  bool forEachPrimaryOrEmptyWithErrors(llvm::function_ref<bool(StringRef)> fn) const{
    if (!hasPrimaries())
      return fn("");
    for (const auto &p: PrimaryInputs)
      if (fn(p.first))
        return true;
    return false;
  }

  // Count-dependend readers:

  /// Return the unique primary input, if one exists.
  const InputFile *getUniquePrimaryInput() const {
    assertMustNotBeMoreThanOnePrimaryInput();
    const auto &b = PrimaryInputs.begin();
    return b == PrimaryInputs.end() ? nullptr : &AllFiles[b->second];
  }

  const InputFile &getRequiredUniquePrimaryInput() const {
    if (const auto *input = getUniquePrimaryInput())
      return *input;
    assert(false);
  }

  /// Return the name of the unique primary input, or an empty StringRef if there
  /// isn't one.
  StringRef getNameOfUniquePrimaryInputFile() const {
    const auto *input = getUniquePrimaryInput();
    return input == nullptr ? StringRef() : input->getFile();
  }

  bool isFilePrimary(StringRef file) {
    StringRef correctedName = file.equals("<stdin>") ? "-" : file;
    auto iterator = PrimaryInputs.find(correctedName);
    return iterator != PrimaryInputs.end() &&
           AllFiles[iterator->second].getIsPrimary();
  }

  unsigned numberOfPrimaryInputsEndingWith(const char *suffix) const;

  // Multi-facet readers

  bool shouldTreatAsSIL() const;

  /// Return true for error
  bool verifyInputs(DiagnosticEngine &diags, bool treatAsSIL,
                    bool isREPLRequested, bool isNoneRequested) const;

  // Writers

  void addInputFile(StringRef file, llvm::MemoryBuffer *buffer = nullptr) {
    addInput(InputFile(file, false, buffer));
  }
  void addPrimaryInputFile(StringRef file,
                           llvm::MemoryBuffer *buffer = nullptr) {
    addInput(InputFile(file.str(), true, buffer));
  }

  void addInput(const InputFile &input) {
    if (input.getIsPrimary()) {
      PrimaryInputs.insert(std::make_pair(input.getFile(), AllFiles.size()));
    }
    AllFiles.push_back(input);
  }
  void clearInputs() {
    AllFiles.clear();
    PrimaryInputs.clear();
  }
};

/// Options for controlling the behavior of the frontend.
class FrontendOptions {
  friend class FrontendArgsToOptionsConverter;

public:
  FrontendInputsAndOutputs InputsAndOutputs;

  /// The kind of input on which the frontend should operate.
  InputFileKind InputKind = InputFileKind::IFK_Swift;

  void forAllOutputPaths(std::function<void(const std::string &)> fn) const;

  /// Gets the name of the specified output filename.
  /// If multiple files are specified, the last one is returned.
  StringRef getSingleOutputFilename(StringRef primaryOrEmpty) {
#error unimp
//    return !primaryOrEmpty.empty() ? outputFilenameForPrimary(primaryOrEmpty)
//    : outputFilenamesForWMO().empty() ? std::string("")
//    : outputFilenamesForWMO().back();
  }
  /// Sets a single filename as output filename.
//  void setSingleOutputFilename(StringRef primaryOrEmpty, const std::string &filename) {
//    if (!primaryOrEmpty.empty())
//      outputFilenameForPrimary(primaryOrEmpty) = filename;
//    else {
//      outputFilenamesForWMO().clear();
//      outputFilenamesForWMO().push_back(filename);
//    }
//  }
//  void setOutputFilenameToStdout(StringRef primaryOrEmpty) { setSingleOutputFilename(primaryOrEmpty, "-"); }
  bool isOutputFilenameStdout(StringRef primaryOrEmpty) {
    return getSingleOutputFilename(primaryOrEmpty) == "-";
  }
  bool hasNamedOutputFile(StringRef primaryOrEmpty) {
    return !isOutputFilenameStdout(primaryOrEmpty);
  }

  /// A list of arbitrary modules to import and make implicitly visible.
  std::vector<std::string> ImplicitImportModuleNames;

  /// The name of the module which the frontend is building.
  std::string ModuleName;

  /// The name of the library to link against when using this module.
  std::string ModuleLinkName;

  /// An Objective-C header to import and make implicitly visible.
  std::string ImplicitObjCHeaderPath;

 

  
 
public:
//  std::string &outputFilenameForPrimary(StringRef pri) { return pathsForPrimary(pri).OutputFilename;}
//  std::string &objCHeaderOutputPathForPrimary(StringRef pri) { return pathsForPrimary(pri).ObjCHeaderOutputPath;}
//  std::string &moduleOutputPathForPrimary(StringRef pri) { return pathsForPrimary(pri).ModuleOutputPath;}
//  std::string &moduleDocOutputPathForPrimary(StringRef pri) { return pathsForPrimary(pri).ModuleDocOutputPath;}
//  std::string &dependenciesFilePathForPrimary(StringRef pri) { return pathsForPrimary(pri).DependenciesFilePath;}
//  std::string &referenceDependenciesFilePathForPrimary(StringRef pri) { return pathsForPrimary(pri).ReferenceDependenciesFilePath;}
//  std::string &serializedDiagnosticsPathForPrimary(StringRef pri) { return pathsForPrimary(pri).SerializedDiagnosticsPath;}
//  std::string &loadedModuleTracePathForPrimary(StringRef pri) { return pathsForPrimary(pri).LoadedModuleTracePath;}
//  std::string &TBDPathForPrimary(StringRef pri) { return pathsForPrimary(pri).TBDPath;}
//
//  std::vector<std::string> &outputFilenamesForWMO() { return pathsForWMO.OutputFilenames;}
//  std::string &objCHeaderOutputPathForWMO() { return pathsForWMO.ObjCHeaderOutputPath;}
//  std::string &moduleOutputPathForWMO() { return pathsForWMO.ModuleOutputPath;}
//  std::string &moduleDocOutputPathForWMO() { return pathsForWMO.ModuleDocOutputPath;}
//  std::string &dependenciesFilePathForWMO() { return pathsForWMO.DependenciesFilePath;}
//  std::string &referenceDependenciesFilePathForWMO() { return pathsForWMO.ReferenceDependenciesFilePath;}
//  std::string &serializedDiagnosticsPathForWMO() { return pathsForWMO.SerializedDiagnosticsPath;}
//  std::string &loadedModuleTracePathForWMO() { return pathsForWMO.LoadedModuleTracePath;}
//  std::string &TBDPathForWMO() { return pathsForWMO.TBDPath;}
  


  /// The path to which we should output fixits as source edits.
  std::string FixitsOutputPath;

  /// Arguments which should be passed in immediate mode.
  std::vector<std::string> ImmediateArgv;

  /// \brief A list of arguments to forward to LLVM's option processing; this
  /// should only be used for debugging and experimental features.
  std::vector<std::string> LLVMArgs;

  /// The path to output swift interface files for the compiled source files.
  std::string DumpAPIPath;

  /// The path to collect the group information for the compiled source files.
  std::string GroupInfoPath;

  /// The path to which we should store indexing data, if any.
  std::string IndexStorePath;

  /// Emit index data for imported serialized swift system modules.
  bool IndexSystemModules = false;

  /// If non-zero, warn when a function body takes longer than this many
  /// milliseconds to type-check.
  ///
  /// Intended for debugging purposes only.
  unsigned WarnLongFunctionBodies = 0;

  /// If non-zero, warn when type-checking an expression takes longer
  /// than this many milliseconds.
  ///
  /// Intended for debugging purposes only.
  unsigned WarnLongExpressionTypeChecking = 0;

  /// If non-zero, overrides the default threshold for how long we let
  /// the expression type checker run before we consider an expression
  /// too complex.
  unsigned SolverExpressionTimeThreshold = 0;

  /// The module for which we should verify all of the generic signatures.
  std::string VerifyGenericSignaturesInModule;

  enum class ActionType {
    NoneAction,        ///< No specific action
    Parse,             ///< Parse only
    Typecheck,         ///< Parse and type-check only
    DumpParse,         ///< Parse only and dump AST
    DumpInterfaceHash, ///< Parse and dump the interface token hash.
    EmitSyntax,        ///< Parse and dump Syntax tree as JSON
    DumpAST,           ///< Parse, type-check, and dump AST
    PrintAST,          ///< Parse, type-check, and pretty-print AST

    /// Parse and dump scope map.
    DumpScopeMaps,

    /// Parse, type-check, and dump type refinement context hierarchy
    DumpTypeRefinementContexts,

    EmitImportedModules, ///< Emit the modules that this one imports
    EmitPCH,             ///< Emit PCH of imported bridging header

    EmitSILGen, ///< Emit raw SIL
    EmitSIL,    ///< Emit canonical SIL

    EmitModuleOnly, ///< Emit module only
    MergeModules,   ///< Merge modules only

    EmitSIBGen, ///< Emit serialized AST + raw SIL
    EmitSIB,    ///< Emit serialized AST + canonical SIL

    Immediate, ///< Immediate mode
    REPL,      ///< REPL mode

    EmitAssembly, ///< Emit assembly
    EmitIR,       ///< Emit LLVM IR
    EmitBC,       ///< Emit LLVM BC
    EmitObject,   ///< Emit object file
  };

  bool isCreatingSIL() { return RequestedAction >= ActionType::EmitSILGen; }

  /// Indicates the action the user requested that the frontend perform.
  ActionType RequestedAction = ActionType::NoneAction;

  /// Indicates that the input(s) should be parsed as the Swift stdlib.
  bool ParseStdlib = false;

  /// If set, emitted module files will always contain options for the
  /// debugger to use.
  bool AlwaysSerializeDebuggingOptions = false;

  /// If set, dumps wall time taken to check each function body to llvm::errs().
  bool DebugTimeFunctionBodies = false;

  /// If set, dumps wall time taken to check each expression.
  bool DebugTimeExpressionTypeChecking = false;

  /// If set, prints the time taken in each major compilation phase to 
  /// llvm::errs().
  ///
  /// \sa swift::SharedTimer
  bool DebugTimeCompilation = false;

  /// The path to which we should output statistics files.
  std::string StatsOutputDir;

  /// Trace changes to stats to files in StatsOutputDir.
  bool TraceStats = false;

  /// If true, serialization encodes an extra lookup table for use in module-
  /// merging when emitting partial modules (the per-file modules in a non-WMO
  /// build).
  bool EnableSerializationNestedTypeLookupTable = true;

  /// Indicates whether or not an import statement can pick up a Swift source
  /// file (as opposed to a module file).
  bool EnableSourceImport = false;

  /// Indicates whether we are compiling for testing.
  ///
  /// \see ModuleDecl::isTestingEnabled
  bool EnableTesting = false;

  /// Enables the "fully resilient" resilience strategy.
  ///
  /// \see ResilienceStrategy::Resilient
  bool EnableResilience = false;

  /// Indicates that the frontend should emit "verbose" SIL
  /// (if asked to emit SIL).
  bool EmitVerboseSIL = false;

  /// If set, this module is part of a mixed Objective-C/Swift framework, and
  /// the Objective-C half should implicitly be visible to the Swift sources.
  bool ImportUnderlyingModule = false;

  /// If set, the header provided in ImplicitObjCHeaderPath will be rewritten
  /// by the Clang importer as part of semantic analysis.
  bool SerializeBridgingHeader = false;

  /// Indicates whether or not the frontend should print statistics upon
  /// termination.
  bool PrintStats = false;

  /// Indicates whether or not the Clang importer should print statistics upon
  /// termination.
  bool PrintClangStats = false;

  /// Indicates whether the playground transformation should be applied.
  bool PlaygroundTransform = false;
  
  /// Indicates whether the AST should be instrumented to simulate a debugger's
  /// program counter. Similar to the PlaygroundTransform, this will instrument
  /// the AST with function calls that get called when you would see a program
  /// counter move in a debugger. To adopt this implement the
  /// __builtin_pc_before and __builtin_pc_after functions.
  bool PCMacro = false;

  /// Indicates whether the playground transformation should omit
  /// instrumentation that has a high runtime performance impact.
  bool PlaygroundHighPerformance = false;

  /// Indicates whether standard help should be shown.
  bool PrintHelp = false;

  /// Indicates whether full help (including "hidden" options) should be shown.
  bool PrintHelpHidden = false;

  /// Should we sort SIL functions, vtables, witness tables, and global
  /// variables by name when we print it out. This eases diffing of SIL files.
  bool EmitSortedSIL = false;

  /// The different modes for validating TBD against the LLVM IR.
  enum class TBDValidationMode {
    None,           ///< Do no validation.
    MissingFromTBD, ///< Only check for symbols that are in IR but not TBD.
    All, ///< Check for symbols that are in IR but not TBD and TBD but not IR.
  };

  /// Compare the symbols in the IR against the TBD file we would generate.
  TBDValidationMode ValidateTBDAgainstIR = TBDValidationMode::None;

  /// The install_name to use in the TBD file.
  std::string TBDInstallName;

  /// An enum with different modes for automatically crashing at defined times.
  enum class DebugCrashMode {
    None, ///< Don't automatically crash.
    AssertAfterParse, ///< Automatically assert after parsing.
    CrashAfterParse, ///< Automatically crash after parsing.
  };

  /// Indicates a debug crash mode for the frontend.
  DebugCrashMode CrashMode = DebugCrashMode::None;

  /// Line and column for each of the locations to be probed by
  /// -dump-scope-maps.
  SmallVector<std::pair<unsigned, unsigned>, 2> DumpScopeMapLocations;

  /// Indicates whether the action will immediately run code.
  static bool isActionImmediate(ActionType);

  /// Return a hash code of any components from these options that should
  /// contribute to a Swift Bridging PCH hash.
  llvm::hash_code getPCHHashComponents() const {
    return llvm::hash_value(0);
  }

  StringRef originalPath(StringRef primaryOrEmpty) const;

  StringRef determineFallbackModuleName() const;

  bool isCompilingExactlyOneSwiftFile() const {
    return InputKind == InputFileKind::IFK_Swift && InputsAndOutputs.hasUniqueInput();
  }

private:
  static const char *suffixForPrincipalOutputFileForAction(ActionType);

  bool hasUnusedDependenciesFilePath(const InputFile &input) const;
  static bool canActionEmitDependencies(ActionType);
  bool hasUnusedObjCHeaderOutputPath(const InputFile &input) const;
  static bool canActionEmitHeader(ActionType);
  bool hasUnusedLoadedModuleTracePath(const InputFile &input) const;
  static bool canActionEmitLoadedModuleTrace(ActionType);
  bool hasUnusedModuleOutputPath(const InputFile &input) const;
  static bool canActionEmitModule(ActionType);
  bool hasUnusedModuleDocOutputPath(const InputFile &input) const;
  static bool canActionEmitModuleDoc(ActionType);

  static bool doesActionProduceOutput(ActionType);
  static bool doesActionProduceTextualOutput(ActionType);
  static bool needsProperModuleName(ActionType);
};

}

#endif
