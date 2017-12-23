//===--- ArgsToFrontendOptionsConverter.h ---------------------------------===//
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

#ifndef ArgsToFrontendOptionsConverter_h
#define ArgsToFrontendOptionsConverter_h

#include "swift/AST/DiagnosticConsumer.h"
#include "swift/AST/DiagnosticEngine.h"
#include "swift/Frontend/FrontendOptions.h"
#include "swift/Option/Options.h"
#include "llvm/Option/ArgList.h"

#include <vector>

using namespace swift;
using namespace llvm::opt;

namespace swift {

/// Parse the command line arguments and fill out all the info in
/// FrontendOptions.

class ArgsToFrontendOptionsConverter {
private:
  DiagnosticEngine &Diags;
  const llvm::opt::ArgList &Args;
  FrontendOptions &Opts;

  Optional<const std::vector<std::string>>
      cachedOutputFilenamesFromCommandLineOrFilelist;

  void handleDebugCrashGroupArguments();

  void computeDebugTimeOptions();
  bool computeFallbackModuleName();
  bool computeModuleName();

  bool computeOutputFilenamesAndSupplementaryFilenames();
  bool computeOutputFilenamesForPrimary(StringRef primaryOrEmpty,
                                        StringRef correspondingOutputFile);

  void computeDumpScopeMapLocations();
  void computeHelpOptions();
  void computeImplicitImportModuleNames();
  void computeImportObjCHeaderOptions();
  void computeLLVMArgs();
  void computePlaygroundOptions();
  void computePrintStatsOptions();
  void computeTBDOptions();

  void setUnsignedIntegerArgument(options::ID optionID, unsigned max,
                                  unsigned &valueToSet);

  bool setUpForSILOrLLVM();

  bool checkUnusedOutputPaths() const;

public:
  ArgsToFrontendOptionsConverter(DiagnosticEngine &Diags,
                                 const llvm::opt::ArgList &Args,
                                 FrontendOptions &Opts)
      : Diags(Diags), Args(Args), Opts(Opts) {}

  bool convert();

  static FrontendOptions::ActionType determineRequestedAction(const ArgList &);
};
} // namespace swift

#endif /* ArgsToFrontendOptionsConverter_h */
