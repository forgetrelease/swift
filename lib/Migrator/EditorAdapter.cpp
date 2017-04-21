//===--- EditorAdapter.cpp ------------------------------------------------===//
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

#include "swift/Basic/SourceLoc.h"
#include "swift/Basic/SourceManager.h"
#include "swift/Migrator/EditorAdapter.h"
#include "clang/Basic/SourceManager.h"

using namespace swift;
using namespace swift::migrator;

clang::FileID
EditorAdapter::getClangFileIDForSwiftBufferID(unsigned BufferID) const {
  /// Check if we already have a mapping for this BufferID.
  auto Found = SwiftToClangBufferMap.find(BufferID);
  if (Found != SwiftToClangBufferMap.end()) {
    return Found->getSecond();
  }

  // If we don't copy the corresponding buffer's text into a new buffer
  // that the ClangSrcMgr can understand.
  auto Text = SwiftSrcMgr.getEntireTextForBuffer(BufferID);
  auto NewBuffer = llvm::MemoryBuffer::getMemBufferCopy(Text);
  auto NewFileID = ClangSrcMgr.createFileID(std::move(NewBuffer));

  SwiftToClangBufferMap.insert({BufferID, NewFileID});

  return NewFileID;
}

clang::SourceLocation
EditorAdapter::translateSourceLoc(SourceLoc SwiftLoc) const {
  auto SwiftBufferID = SwiftSrcMgr.findBufferContainingLoc(SwiftLoc);
  auto Offset = SwiftSrcMgr.getLocOffsetInBuffer(SwiftLoc, SwiftBufferID);

  auto ClangFileID = getClangFileIDForSwiftBufferID(SwiftBufferID);
  return ClangSrcMgr.getLocForStartOfFile(ClangFileID).getLocWithOffset(Offset);
}

clang::SourceRange
EditorAdapter::translateSourceRange(SourceRange SwiftSourceRange) const {
  auto Start = translateSourceLoc(SwiftSourceRange.Start);
  auto End = translateSourceLoc(SwiftSourceRange.End);
  return clang::SourceRange { Start, End };
}

clang::CharSourceRange EditorAdapter::
translateCharSourceRange(CharSourceRange SwiftSourceSourceRange) const {
  auto ClangStartLoc = translateSourceLoc(SwiftSourceSourceRange.getStart());
  auto ClangEndLoc = translateSourceLoc(SwiftSourceSourceRange.getEnd());
  return clang::CharSourceRange::getCharRange(ClangStartLoc, ClangEndLoc);
}

bool EditorAdapter::insertFromRange(SourceLoc Loc, CharSourceRange Range,
                                    bool AfterToken,
                                    bool BeforePreviousInsertions) {
  auto ClangLoc = translateSourceLoc(Loc);
  auto ClangCharRange = translateCharSourceRange(Range);
  return Edits.insertFromRange(ClangLoc, ClangCharRange, AfterToken,
                               BeforePreviousInsertions);
}

bool EditorAdapter::insertWrap(StringRef Before, CharSourceRange Range,
                               StringRef After) {
  auto ClangRange = translateCharSourceRange(Range);
  return Edits.insertWrap(Before, ClangRange, After);
}

bool EditorAdapter::remove(CharSourceRange Range) {
  auto ClangRange = translateCharSourceRange(Range);
  return Edits.remove(ClangRange);
}

bool EditorAdapter::replace(CharSourceRange Range, StringRef Text) {
  auto ClangRange = translateCharSourceRange(Range);
  return Edits.replace(ClangRange, Text);
}

bool EditorAdapter::replaceWithInner(CharSourceRange Range,
                                     CharSourceRange InnerRange) {
  auto ClangRange = translateCharSourceRange(Range);
  auto ClangInnerRange = translateCharSourceRange(InnerRange);
  return Edits.replaceWithInner(ClangRange, ClangInnerRange);
}
bool EditorAdapter::replaceText(SourceLoc Loc, StringRef Text,
                 StringRef ReplacementText) {
  auto ClangLoc = translateSourceLoc(Loc);
  return Edits.replaceText(ClangLoc, Text, ReplacementText);
}

bool EditorAdapter::insertFromRange(SourceLoc Loc, SourceRange TokenRange,
                     bool AfterToken,
                     bool BeforePreviousInsertions) {
  CharSourceRange CharRange { SwiftSrcMgr, TokenRange.Start, TokenRange.End };
  return insertFromRange(Loc, CharRange,
                         AfterToken, BeforePreviousInsertions);
}

bool EditorAdapter::insertWrap(StringRef Before, SourceRange TokenRange,
                               StringRef After) {
  CharSourceRange CharRange { SwiftSrcMgr, TokenRange.Start, TokenRange.End };
  return insertWrap(Before, CharRange, After);
}

bool EditorAdapter::remove(SourceRange TokenRange) {
  CharSourceRange CharRange { SwiftSrcMgr, TokenRange.Start, TokenRange.End };
  return remove(CharRange);
}

bool EditorAdapter::replace(SourceRange TokenRange, StringRef Text) {
  CharSourceRange CharRange { SwiftSrcMgr, TokenRange.Start, TokenRange.End };
  return replace(CharRange, Text);
}

bool EditorAdapter::replaceWithInner(SourceRange TokenRange,
                                     SourceRange TokenInnerRange) {
  CharSourceRange CharRange { SwiftSrcMgr, TokenRange.Start, TokenRange.End };
  CharSourceRange CharInnerRange {
    SwiftSrcMgr, TokenInnerRange.Start, TokenInnerRange.End
  };
  return replaceWithInner(CharRange, CharInnerRange);
}
