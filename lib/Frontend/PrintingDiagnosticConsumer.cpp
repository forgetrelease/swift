//===--- PrintingDiagnosticConsumer.cpp - Print Text Diagnostics ----------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
//  This file implements the PrintingDiagnosticConsumer class.
//
//===----------------------------------------------------------------------===//

#include "swift/Frontend/PrintingDiagnosticConsumer.h"
#include "swift/AST/DiagnosticEngine.h"
#include "swift/Basic/LLVM.h"
#include "swift/Basic/SourceManager.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Support/FormatAdapters.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>

using namespace swift;

namespace {
  class ColoredStream : public raw_ostream {
    raw_ostream &Underlying;
  public:
    explicit ColoredStream(raw_ostream &underlying) : Underlying(underlying) {}
    ~ColoredStream() override { flush(); }

    raw_ostream &changeColor(Colors color, bool bold = false,
                             bool bg = false) override {
      Underlying.changeColor(color, bold, bg);
      return *this;
    }
    raw_ostream &resetColor() override {
      Underlying.resetColor();
      return *this;
    }
    raw_ostream &reverseColor() override {
      Underlying.reverseColor();
      return *this;
    }
    bool has_colors() const override {
      return true;
    }

    void write_impl(const char *ptr, size_t size) override {
      Underlying.write(ptr, size);
    }
    uint64_t current_pos() const override {
      return Underlying.tell() - GetNumBytesInBuffer();
    }

    size_t preferred_buffer_size() const override {
      return 0;
    }
  };

  /// A stream which drops all color settings.
  class NoColorStream : public raw_ostream {
    raw_ostream &Underlying;

  public:
    explicit NoColorStream(raw_ostream &underlying) : Underlying(underlying) {}
    ~NoColorStream() override { flush(); }

    bool has_colors() const override { return false; }

    void write_impl(const char *ptr, size_t size) override {
      Underlying.write(ptr, size);
    }
    uint64_t current_pos() const override {
      return Underlying.tell() - GetNumBytesInBuffer();
    }

    size_t preferred_buffer_size() const override { return 0; }
  };

  // MARK: Experimental diagnostic printing.

  static void printDiagnosticKind(DiagnosticKind kind, raw_ostream &out) {
    switch (kind) {
    case DiagnosticKind::Error:
      out.changeColor(ColoredStream::Colors::RED, true);
      out << "error:";
      break;
    case DiagnosticKind::Warning:
      out.changeColor(ColoredStream::Colors::YELLOW, true);
      out << "warning:";
      break;
    case DiagnosticKind::Note:
      out.changeColor(ColoredStream::Colors::CYAN, true);
      out << "note:";
      break;
    case DiagnosticKind::Remark:
      out.changeColor(ColoredStream::Colors::CYAN, true);
      out << "remark:";
      break;
    }
    out.resetColor();
  }

  static void printNumberedGutter(unsigned LineNumber,
                                  unsigned LineNumberIndent, raw_ostream &Out) {
    Out.changeColor(ColoredStream::Colors::BLUE, true);
    Out << llvm::formatv(
        "{0} | ",
        llvm::fmt_align(LineNumber, llvm::AlignStyle::Right, LineNumberIndent));
    Out.resetColor();
  }

  static void printEmptyGutter(unsigned LineNumberIndent, raw_ostream &Out) {
    Out.changeColor(ColoredStream::Colors::BLUE, true);
    Out << std::string(LineNumberIndent + 1, ' ') << "| ";
    Out.resetColor();
  }

  // Describe a fix-it out-of-line.
  static void describeFixIt(SourceManager &SM, DiagnosticInfo::FixIt fixIt,
                            raw_ostream &Out) {
    if (fixIt.getRange().getByteLength() == 0) {
      Out << "insert '" << fixIt.getText() << "'";
    } else if (fixIt.getText().empty()) {
      Out << "remove '" << SM.extractText(fixIt.getRange()) << "'";
    } else {
      Out << "replace '" << SM.extractText(fixIt.getRange()) << "' with '"
          << fixIt.getText() << "'";
    }
  }

  static void describeFixIts(SourceManager &SM,
                             ArrayRef<DiagnosticInfo::FixIt> fixIts,
                             raw_ostream &Out) {
    Out << "[";
    for (unsigned i = 0; i < fixIts.size(); ++i) {
      if (fixIts.size() > 2 && i + 1 == fixIts.size()) {
        Out << ", and ";
      } else if (fixIts.size() > 2 && i > 0) {
        Out << ", ";
      } else if (fixIts.size() == 2 && i == 1) {
        Out << " and ";
      }
      describeFixIt(SM, fixIts[i], Out);
    }
    Out << "]";
  }

  /// Represents a single line of source code annotated with optional messages,
  /// highlights, and fix-its.
  class AnnotatedLine {
    friend class AnnotatedFileExcerpt;

    // A diagnostic message located at a specific byte in the line.
    struct Message {
      unsigned Byte;
      DiagnosticKind Kind;
      std::string Text;
    };

    // A half-open byte range which should be highlighted.
    struct Highlight {
      unsigned StartByte;
      unsigned EndByte;
    };

    // A half-open byte range which should be replaced with the given text.
    struct FixIt {
      unsigned StartByte;
      unsigned EndByte;
      std::string Text;
    };

    unsigned LineNumber;
    std::string LineText;
    SmallVector<Message, 1> Messages;
    SmallVector<Highlight, 1> Highlights;
    SmallVector<FixIt, 1> FixIts;

    // Adjust output color as needed if this byte is part of a fix-it deletion.
    void applyStyleForLineByte(unsigned Byte, raw_ostream &Out, bool &Deleted) {
      bool shouldDelete = false;

      for (auto fixIt : FixIts) {
        if (Byte >= fixIt.StartByte && Byte < fixIt.EndByte)
          shouldDelete = true;
      }

      // Only modify deletions when we reach the start or end of
      // a fix-it. This ensures that so long as the original
      // SourceLocs pointed to the first byte of a grapheme cluster, we won't
      // output an ANSI escape sequence in the middle of one.
      if (shouldDelete != Deleted) {
        Out.resetColor();
        if (shouldDelete) {
          Out.changeColor(ColoredStream::Colors::RED);
        }
      }
      Deleted = shouldDelete;
    }

    // Insert fix-it replacement text at the appropriate point in the line.
    bool maybePrintInsertionAfter(int Byte, bool isLineASCII,
                                  raw_ostream &Out) {
      if (!isLineASCII)
        return false;

      for (auto fixIt : FixIts) {
        if ((int)fixIt.EndByte - 1 == Byte) {
          Out.changeColor(ColoredStream::Colors::GREEN, /*bold*/ true);
          for (unsigned i = 0; i < fixIt.Text.size(); ++i) {
            // Invert text colors for editor placeholders.
            if (i + 1 < fixIt.Text.size() && fixIt.Text.substr(i, 2) == "<#") {
              Out.changeColor(ColoredStream::Colors::GREEN, /*bold*/ true,
                              /*background*/ true);
              ++i;
            } else if (i + 1 < fixIt.Text.size() &&
                       fixIt.Text.substr(i, 2) == "#>") {
              Out.changeColor(ColoredStream::Colors::GREEN, /*bold*/ true,
                              /*background*/ false);
              ++i;
            } else {
              Out << fixIt.Text[i];
            }
          }
          Out.resetColor();
          return true;
        }
      }
      return false;
    }

    unsigned lineByteOffsetForLoc(SourceManager &SM, SourceLoc Loc) {
      SourceLoc lineStart = SM.getLocForLineCol(SM.findBufferContainingLoc(Loc),
                                                getLineNumber(), 1);
      return SM.getByteDistance(lineStart, Loc);
    }

  public:
    AnnotatedLine(unsigned LineNumber, StringRef LineText)
        : LineNumber(LineNumber), LineText(LineText) {}

    unsigned getLineNumber() { return LineNumber; }

    void addMessage(SourceManager &SM, SourceLoc Loc, DiagnosticKind Kind,
                    StringRef Message) {
      Messages.push_back({lineByteOffsetForLoc(SM, Loc), Kind, Message});
    }

    void addHighlight(SourceManager &SM, CharSourceRange Range) {
      Highlights.push_back({lineByteOffsetForLoc(SM, Range.getStart()),
                            lineByteOffsetForLoc(SM, Range.getEnd())});
    }

    void addFixIt(SourceManager &SM, CharSourceRange Range, StringRef Text) {
      FixIts.push_back({lineByteOffsetForLoc(SM, Range.getStart()),
                        lineByteOffsetForLoc(SM, Range.getEnd()), Text});
    }

    void render(unsigned LineNumberIndent, raw_ostream &Out) {
      printNumberedGutter(LineNumber, LineNumberIndent, Out);

      // Determine if the line is all-ASCII. This will determine a number of
      // later formatting decisions.
      bool isASCII = true;
      for (unsigned i = 0; i < LineText.size(); ++i)
        isASCII = isASCII && static_cast<unsigned char>(LineText[i]) <= 127;

      // Map a byte in the original source line to a column in the annotated
      // line.
      unsigned *byteToColumnMap = new unsigned[LineText.size() + 1];
      unsigned extraColumns = 0;
      // We count one past the end of LineText to handle trailing fix-it
      // insertions.
      for (unsigned i = 0; i < LineText.size() + 1; ++i) {
        if (isASCII) {
          for (auto fixIt : FixIts) {
            if (fixIt.EndByte == i) {
              extraColumns += fixIt.Text.size() -
                              StringRef(fixIt.Text).count("<#") * 2 -
                              StringRef(fixIt.Text).count("#>") * 2;
            }
          }
        }
        // Tabs are mapped to 2 spaces so they have a known column width.
        if (i < LineText.size() && LineText[i] == '\t')
          extraColumns += 1;

        byteToColumnMap[i] = i + extraColumns;
      }

      // Print the source line byte-by-byte, emitting ANSI escape sequences as
      // needed to style fix-its, and checking for non-ASCII characters.
      bool deleted = false;
      maybePrintInsertionAfter(-1, isASCII, Out);
      for (unsigned i = 0; i < LineText.size(); ++i) {
        applyStyleForLineByte(i, Out, deleted);
        if (LineText[i] == '\t')
          Out << "  ";
        else
          Out << LineText[i];
        if (maybePrintInsertionAfter(i, isASCII, Out)) {
          deleted = false;
        }
      }
      maybePrintInsertionAfter(LineText.size(), isASCII, Out);
      Out.resetColor();
      Out << "\n";

      // If the entire line is composed of ASCII characters, we can position '~'
      // characters in the appropriate columns on the following line to
      // represent highlights.
      if (isASCII) {
        auto highlightLine = std::string(byteToColumnMap[LineText.size()], ' ');
        for (auto highlight : Highlights) {
          for (unsigned i = highlight.StartByte; i < highlight.EndByte; ++i)
            highlightLine[byteToColumnMap[i]] = '~';
        }

        for (auto fixIt : FixIts) {
          // Mark deletions.
          for (unsigned i = fixIt.StartByte; i < fixIt.EndByte; ++i)
            highlightLine[byteToColumnMap[i]] = '-';

          // Mark insertions.
          for (unsigned i = byteToColumnMap[fixIt.StartByte - 1] + 1;
               i < byteToColumnMap[fixIt.StartByte]; ++i)
            highlightLine[i] = '+';
        }

        if (!(Highlights.empty() && FixIts.empty())) {
          printEmptyGutter(LineNumberIndent, Out);
          auto currentColor = ColoredStream::Colors::WHITE;
          for (unsigned i = 0; i < highlightLine.size(); ++i) {
            llvm::raw_ostream::Colors charColor;
            switch (highlightLine[i]) {
            case '+':
              charColor = ColoredStream::Colors::GREEN;
              break;
            case '-':
              charColor = ColoredStream::Colors::RED;
              break;
            case '~':
              charColor = ColoredStream::Colors::BLUE;
              break;
            default:
              charColor = ColoredStream::Colors::WHITE;
              break;
            }
            if (currentColor != charColor) {
              currentColor = charColor;
              Out.changeColor(charColor, /*bold*/ true);
            }
            Out << highlightLine[i];
          }
          Out.resetColor();
          Out << "\n";
        }
      }

      // Print each message on its own line below the source line. If the source
      // line is ASCII, we can insert a caret pointing directly to the message
      // location. If not, use a more generic "-->" indicator.
      // FIXME: Improve Unicode support so every message can include a direct
      // location indicator.
      for (auto msg : Messages) {
        printEmptyGutter(LineNumberIndent, Out);
        if (isASCII) {
          Out << std::string(byteToColumnMap[msg.Byte], ' ') << "^ ";
          printDiagnosticKind(msg.Kind, Out);
          Out << " " << msg.Text << "\n";
        } else {
          Out << "--> ";
          printDiagnosticKind(msg.Kind, Out);
          Out << " " << msg.Text << "\n";
        }
      }
      delete[] byteToColumnMap;
    }
  };

  /// Represents an excerpt of a source file which contains one or more
  /// annotated source lines.
  class AnnotatedFileExcerpt {
    SourceManager &SM;
    unsigned BufferID;
    /// The primary location of the parent error/warning/remark for this
    /// diagnostic message. This is printed alongside the file path so it can be
    /// parsed by editors and other tooling.
    SourceLoc PrimaryLoc;
    std::vector<AnnotatedLine> AnnotatedLines;

    /// Return the AnnotatedLine for a given SourceLoc, creating it if it
    /// doesn't already exist.
    AnnotatedLine &lineForLoc(SourceLoc Loc) {
      // FIXME: This call to `getLineAndColumn` is expensive.
      unsigned lineNo = SM.getLineAndColumn(Loc).first;
      AnnotatedLine newLine(lineNo, "");
      auto iter =
          std::lower_bound(AnnotatedLines.begin(), AnnotatedLines.end(),
                           newLine, [](AnnotatedLine l1, AnnotatedLine l2) {
                             return l1.getLineNumber() < l2.getLineNumber();
                           });
      if (iter == AnnotatedLines.end() || iter->getLineNumber() != lineNo) {
        newLine.LineText = SM.getLineString(BufferID, lineNo);
        return *AnnotatedLines.insert(iter, newLine);
      } else {
        return *iter;
      }
    }

    unsigned getLineNumberIndent() {
      // The lines are already in sorted ascending order, and we render one line
      // after the last one for context. Use the last line number plus one to
      // determine the indent.
      return floor(1 + log10(AnnotatedLines.back().getLineNumber() + 1));
    }

    void printNumberedLine(SourceManager &SM, unsigned BufferID,
                           unsigned LineNumber, unsigned LineNumberIndent,
                           raw_ostream &Out) {
      printNumberedGutter(LineNumber, LineNumberIndent, Out);
      Out << SM.getLineString(BufferID, LineNumber) << "\n";
    }

    void lineRangesForRange(CharSourceRange Range,
                            SmallVectorImpl<CharSourceRange> &LineRanges) {
      // FIXME: The calls to `getLineAndColumn` and `getLocForLineCol` are
      // expensive.
      unsigned startLineNo = SM.getLineAndColumn(Range.getStart()).first;
      unsigned endLineNo = SM.getLineAndColumn(Range.getEnd()).first;

      if (startLineNo == endLineNo) {
        LineRanges.push_back(Range);
        return;
      }

      // Split the range by line.
      SourceLoc lineEnd = SM.getLocForOffset(
          BufferID, *SM.resolveOffsetForEndOfLine(BufferID, startLineNo));
      LineRanges.push_back(CharSourceRange(SM, Range.getStart(), lineEnd));

      for (unsigned intermediateLine = startLineNo + 1;
           intermediateLine < endLineNo; ++intermediateLine) {
        SourceLoc lineStart =
            SM.getLocForLineCol(BufferID, intermediateLine, 1);
        SourceLoc lineEnd = SM.getLocForOffset(
            BufferID,
            *SM.resolveOffsetForEndOfLine(BufferID, intermediateLine));
        LineRanges.push_back(CharSourceRange(SM, lineStart, lineEnd));
      }

      SourceLoc lastLineStart = SM.getLocForLineCol(BufferID, endLineNo, 1);
      LineRanges.push_back(CharSourceRange(SM, lastLineStart, Range.getEnd()));
    }

  public:
    AnnotatedFileExcerpt(SourceManager &SM, unsigned BufferID,
                         SourceLoc PrimaryLoc)
        : SM(SM), BufferID(BufferID), PrimaryLoc(PrimaryLoc) {}

    void addMessage(SourceLoc Loc, DiagnosticKind Kind, StringRef Message) {
      lineForLoc(Loc).addMessage(SM, Loc, Kind, Message);
    }

    void addHighlight(CharSourceRange Range) {
      SmallVector<CharSourceRange, 1> ranges;
      lineRangesForRange(Range, ranges);
      for (auto lineRange : ranges)
        lineForLoc(lineRange.getStart()).addHighlight(SM, lineRange);
    }

    void addFixIt(CharSourceRange Range, StringRef Text) {
      SmallVector<CharSourceRange, 1> ranges;
      lineRangesForRange(Range, ranges);
      // The removals are broken down line-by-line, so only add any insertions
      // to the last replacement.
      auto last = ranges.pop_back_val();
      lineForLoc(last.getStart()).addFixIt(SM, last, Text);
      for (auto lineRange : ranges)
        lineForLoc(lineRange.getStart()).addFixIt(SM, lineRange, "");
    }

    void render(raw_ostream &Out) {
      // Tha maximum number of intermediate lines without annotations to render
      // between annotated lines before using an ellipsis.
      static const unsigned maxIntermediateLines = 3;

      assert(!AnnotatedLines.empty() && "File excerpt has no lines");
      unsigned lineNumberIndent = getLineNumberIndent();

      // Print the file name at the top of each excerpt.
      auto primaryLineAndColumn = SM.getLineAndColumn(PrimaryLoc);
      Out.changeColor(ColoredStream::Colors::MAGENTA, /*bold*/ true);
      Out << SM.getIdentifierForBuffer(BufferID) << ":"
          << primaryLineAndColumn.first << ":" << primaryLineAndColumn.second
          << "\n";
      Out.resetColor();

      // Print one extra line at the top for context.
      if (AnnotatedLines.front().getLineNumber() > 0)
        printNumberedLine(SM, BufferID,
                          AnnotatedLines.front().getLineNumber() - 1,
                          lineNumberIndent, Out);

      // Render the first annotated line.
      AnnotatedLines.front().render(lineNumberIndent, Out);
      unsigned lastLineNumber = AnnotatedLines.front().getLineNumber();

      // Render intermediate lines/ellipsis, followed by the next annotated
      // line until they have all been output.
      for (auto line = AnnotatedLines.begin() + 1; line != AnnotatedLines.end();
           ++line) {
        unsigned lineNumber = line->getLineNumber();
        if (lineNumber - lastLineNumber > maxIntermediateLines) {
          // Use an ellipsis to denote an ommitted part of the file.
          printNumberedLine(SM, BufferID, lastLineNumber + 1, lineNumberIndent,
                            Out);
          Out.changeColor(ColoredStream::Colors::BLUE, true);
          Out << llvm::formatv("{0}...\n",
                               llvm::fmt_repeat(" ", lineNumberIndent));
          Out.resetColor();
          printNumberedLine(SM, BufferID, lineNumber - 1, lineNumberIndent,
                            Out);
        } else {
          // Print all the intermediate lines.
          for (unsigned l = lastLineNumber + 1; l < lineNumber; ++l) {
            printNumberedLine(SM, BufferID, l, lineNumberIndent, Out);
          }
        }
        // Print the annotated line.
        line->render(lineNumberIndent, Out);
        lastLineNumber = lineNumber;
      }
      // Print one extra line at the bottom for context.
      printNumberedLine(
          SM, BufferID,
          AnnotatedLines[AnnotatedLines.size() - 1].getLineNumber() + 1,
          lineNumberIndent, Out);
    }
  };
} // end anonymous namespace

namespace swift {
/// Represents one or more annotated file snippets which together form a
/// complete diagnostic message.
class AnnotatedSourceSnippet {
  SourceManager &SM;
  std::map<unsigned, AnnotatedFileExcerpt> FileExcerpts;
  SmallVector<std::pair<DiagnosticKind, std::string>, 1>
      UnknownLocationMessages;

  AnnotatedFileExcerpt &excerptForLoc(SourceLoc Loc) {
    unsigned bufID = SM.findBufferContainingLoc(Loc);
    FileExcerpts.emplace(bufID, AnnotatedFileExcerpt(SM, bufID, Loc));
    return FileExcerpts.find(bufID)->second;
  }

public:
  AnnotatedSourceSnippet(SourceManager &SM) : SM(SM){};

  void addMessage(SourceLoc Loc, DiagnosticKind Kind, StringRef Message) {
    if (Loc.isInvalid()) {
      UnknownLocationMessages.push_back({Kind, Message.str()});
      return;
    }
    excerptForLoc(Loc).addMessage(Loc, Kind, Message);
  }

  void addHighlight(CharSourceRange Range) {
    if (Range.isInvalid())
      return;
    excerptForLoc(Range.getStart()).addHighlight(Range);
  }

  void addFixIt(CharSourceRange Range, StringRef Text) {
    if (Range.isInvalid())
      return;
    excerptForLoc(Range.getStart()).addFixIt(Range, Text);
  }

  void render(raw_ostream &Out) {
    // Print the excerpt for each file.
    for (auto excerpt : FileExcerpts)
      excerpt.second.render(Out);

    // Handle messages with invalid locations.
    if (!UnknownLocationMessages.empty()) {
      Out.changeColor(ColoredStream::Colors::MAGENTA, /*bold*/ true);
      Out << "Unknown Location\n";
      Out.resetColor();
    }
    for (auto unknownMessage : UnknownLocationMessages) {
      printEmptyGutter(2, Out);
      printDiagnosticKind(unknownMessage.first, Out);
      Out << " " << unknownMessage.second << "\n";
    }
  }
};
} // namespace swift

static void annotateSnippetWithInfo(SourceManager &SM,
                                    const DiagnosticInfo &Info,
                                    AnnotatedSourceSnippet &Snippet) {
  llvm::SmallString<256> Text;
  {
    llvm::raw_svector_ostream Out(Text);
    DiagnosticEngine::formatDiagnosticText(Out, Info.FormatString,
                                           Info.FormatArgs);
    // Show associated fix-its as part of the message. This is a
    // better experience when notes offer a choice of fix-its. It's redundant
    // for fix-its which are also displayed inline, but helps improve
    // readability in some situations.
    if (!Info.FixIts.empty()) {
      Out << " ";
      describeFixIts(SM, Info.FixIts, Out);
    }
  }

  Snippet.addMessage(Info.Loc, Info.Kind, Text);
  for (auto range : Info.Ranges) {
    Snippet.addHighlight(range);
  }

  // Don't print inline fix-its for notes.
  if (Info.Kind != DiagnosticKind::Note) {
    for (auto fixIt : Info.FixIts) {
      Snippet.addFixIt(fixIt.getRange(), fixIt.getText());
    }
  }
  // Add any explicitly grouped notes to the snippet.
  for (auto ChildInfo : Info.ChildDiagnosticInfo) {
    annotateSnippetWithInfo(SM, *ChildInfo, Snippet);
  }
}

// MARK: Main DiagnosticConsumer entrypoint.
void PrintingDiagnosticConsumer::handleDiagnostic(SourceManager &SM,
                                                  const DiagnosticInfo &Info) {
  if (Info.Kind == DiagnosticKind::Error) {
    DidErrorOccur = true;
  }

  if (Info.IsChildNote)
    return;

  if (ExperimentalFormattingEnabled) {
    if (Info.Kind == DiagnosticKind::Note && currentSnippet) {
      // If this is a note and we have an in-flight message, add it to that
      // instead of emitting it separately.
      annotateSnippetWithInfo(SM, Info, *currentSnippet);
    } else {
      // If we encounter a new error/warning/remark, flush any in-flight
      // snippets.
      flush(/*includeTrailingBreak*/ true);
      currentSnippet = std::make_unique<AnnotatedSourceSnippet>(SM);
      annotateSnippetWithInfo(SM, Info, *currentSnippet);
    }
  } else {
    printDiagnostic(SM, Info);

    for (auto path : Info.EducationalNotePaths) {
      if (auto buffer = SM.getFileSystem()->getBufferForFile(path))
        Stream << buffer->get()->getBuffer() << "\n";
    }

    for (auto ChildInfo : Info.ChildDiagnosticInfo) {
      printDiagnostic(SM, *ChildInfo);
    }
  }
}

void PrintingDiagnosticConsumer::flush(bool includeTrailingBreak) {
  if (currentSnippet) {
    if (ForceColors) {
      ColoredStream colorStream{Stream};
      currentSnippet->render(colorStream);
      if (includeTrailingBreak)
        colorStream << "\n\n";
    } else {
      NoColorStream noColorStream{Stream};
      currentSnippet->render(noColorStream);
      if (includeTrailingBreak)
        noColorStream << "\n\n";
    }
    currentSnippet.reset();
  }
}

bool PrintingDiagnosticConsumer::finishProcessing() {
  // If there's an in-flight snippet, flush it.
  flush();
  return false;
}

// MARK: LLVM style diagnostic printing
void PrintingDiagnosticConsumer::printDiagnostic(SourceManager &SM,
                                                 const DiagnosticInfo &Info) {

  // Determine what kind of diagnostic we're emitting.
  llvm::SourceMgr::DiagKind SMKind;
  switch (Info.Kind) {
  case DiagnosticKind::Error:
    SMKind = llvm::SourceMgr::DK_Error;
    break;
  case DiagnosticKind::Warning:
    SMKind = llvm::SourceMgr::DK_Warning;
    break;

  case DiagnosticKind::Note:
    SMKind = llvm::SourceMgr::DK_Note;
    break;

  case DiagnosticKind::Remark:
    SMKind = llvm::SourceMgr::DK_Remark;
    break;
  }

  // Translate ranges.
  SmallVector<llvm::SMRange, 2> Ranges;
  for (auto R : Info.Ranges)
    Ranges.push_back(getRawRange(SM, R));

  // Translate fix-its.
  SmallVector<llvm::SMFixIt, 2> FixIts;
  for (DiagnosticInfo::FixIt F : Info.FixIts)
    FixIts.push_back(getRawFixIt(SM, F));

  // Display the diagnostic.
  ColoredStream coloredErrs{Stream};
  raw_ostream &out = ForceColors ? coloredErrs : Stream;
  const llvm::SourceMgr &rawSM = SM.getLLVMSourceMgr();
  
  // Actually substitute the diagnostic arguments into the diagnostic text.
  llvm::SmallString<256> Text;
  {
    llvm::raw_svector_ostream Out(Text);
    DiagnosticEngine::formatDiagnosticText(Out, Info.FormatString,
                                           Info.FormatArgs);
  }

  auto Msg = SM.GetMessage(Info.Loc, SMKind, Text, Ranges, FixIts);
  rawSM.PrintMessage(out, Msg, ForceColors);
}

llvm::SMDiagnostic
SourceManager::GetMessage(SourceLoc Loc, llvm::SourceMgr::DiagKind Kind,
                          const Twine &Msg,
                          ArrayRef<llvm::SMRange> Ranges,
                          ArrayRef<llvm::SMFixIt> FixIts) const {

  // First thing to do: find the current buffer containing the specified
  // location to pull out the source line.
  SmallVector<std::pair<unsigned, unsigned>, 4> ColRanges;
  std::pair<unsigned, unsigned> LineAndCol;
  StringRef BufferID = "<unknown>";
  std::string LineStr;

  if (Loc.isValid()) {
    BufferID = getDisplayNameForLoc(Loc);
    auto CurMB = LLVMSourceMgr.getMemoryBuffer(findBufferContainingLoc(Loc));

    // Scan backward to find the start of the line.
    const char *LineStart = Loc.Value.getPointer();
    const char *BufStart = CurMB->getBufferStart();
    while (LineStart != BufStart && LineStart[-1] != '\n' &&
           LineStart[-1] != '\r')
      --LineStart;

    // Get the end of the line.
    const char *LineEnd = Loc.Value.getPointer();
    const char *BufEnd = CurMB->getBufferEnd();
    while (LineEnd != BufEnd && LineEnd[0] != '\n' && LineEnd[0] != '\r')
      ++LineEnd;
    LineStr = std::string(LineStart, LineEnd);

    // Convert any ranges to column ranges that only intersect the line of the
    // location.
    for (unsigned i = 0, e = Ranges.size(); i != e; ++i) {
      llvm::SMRange R = Ranges[i];
      if (!R.isValid()) continue;

      // If the line doesn't contain any part of the range, then ignore it.
      if (R.Start.getPointer() > LineEnd || R.End.getPointer() < LineStart)
        continue;

      // Ignore pieces of the range that go onto other lines.
      if (R.Start.getPointer() < LineStart)
        R.Start = llvm::SMLoc::getFromPointer(LineStart);
      if (R.End.getPointer() > LineEnd)
        R.End = llvm::SMLoc::getFromPointer(LineEnd);

      // Translate from SMLoc ranges to column ranges.
      // FIXME: Handle multibyte characters.
      ColRanges.push_back(std::make_pair(R.Start.getPointer()-LineStart,
                                         R.End.getPointer()-LineStart));
    }

    LineAndCol = getLineAndColumn(Loc);
  }

  return llvm::SMDiagnostic(LLVMSourceMgr, Loc.Value, BufferID,
                            LineAndCol.first,
                            LineAndCol.second-1, Kind, Msg.str(),
                            LineStr, ColRanges, FixIts);
}

// These must come after the declaration of AnnotatedSourceSnippet due to the
// `currentSnippet` member.
PrintingDiagnosticConsumer::PrintingDiagnosticConsumer(
    llvm::raw_ostream &stream)
    : Stream(stream) {}
PrintingDiagnosticConsumer::~PrintingDiagnosticConsumer() = default;

// FIXME: This implementation is inefficient.
std::string SourceManager::getLineString(unsigned BufferID,
                                         unsigned LineNumber) {
  SourceLoc Loc = getLocForLineCol(BufferID, LineNumber, 1);
  auto CurMB = LLVMSourceMgr.getMemoryBuffer(findBufferContainingLoc(Loc));
  const char *LineStart = Loc.Value.getPointer();
  const char *BufStart = CurMB->getBufferStart();
  while (LineStart != BufStart && LineStart[-1] != '\n' &&
         LineStart[-1] != '\r')
    --LineStart;

  // Get the end of the line.
  const char *LineEnd = Loc.Value.getPointer();
  const char *BufEnd = CurMB->getBufferEnd();
  while (LineEnd != BufEnd && LineEnd[0] != '\n' && LineEnd[0] != '\r')
    ++LineEnd;
  return std::string(LineStart, LineEnd);
}
