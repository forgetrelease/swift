//===--- ASTMigratorPass.h --------------------------------------*- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// A base class for a syntactic migrator pass that uses the temporary
// swift::migrator::EditorAdapter infrastructure.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_MIGRATOR_ASTMIGRATORPASS_H
#define SWIFT_MIGRATOR_ASTMIGRATORPASS_H

#include "swift/AST/ASTContext.h"
#include "swift/Migrator/EditorAdapter.h"

namespace swift {
class SourceManager;
struct MigratorOptions;

namespace migrator {
class ASTMigratorPass {
protected:
  EditorAdapter &Editor;
  SourceFile *SF;
  const MigratorOptions &Opts;
  const StringRef Filename;
  const unsigned BufferID;
  SourceManager &SM;

  ASTMigratorPass(EditorAdapter &Editor, SourceFile *SF,
                  const MigratorOptions &Opts)
    : Editor(Editor), SF(SF), Opts(Opts), Filename(SF->getFilename()),
      BufferID(SF->getBufferID().getValue()),
      SM(SF->getASTContext().SourceMgr) {}
};

/// Run a general pass to migrate code based on SDK differences in the previous
/// release.
void runAPIDiffMigratorPass(EditorAdapter &Editor,
                            SourceFile *SF,
                            const MigratorOptions &Opts);

/// Run a pass to fix up new tuple interpretation in SE-0110.
void runTupleSplatMigratorPass(EditorAdapter &Editor,
                               SourceFile *SF,
                               const MigratorOptions &Opts);

/// Run a pass to prepend 'Swift.' to `type(of:)` expressions if they will
/// be shadowed in Swift 4, as these are now resolved by normal overload
/// resolution.
void runTypeOfMigratorPass(EditorAdapter &Editor,
                           SourceFile *SF,
                           const MigratorOptions &Opts);

} // end namespace migrator
} // end namespace swift

#endif // SWIFT_MIGRATOR_ASTMIGRATORPASS_H
