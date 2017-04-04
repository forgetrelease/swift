//===--- ParseableOutput.cpp - Helpers for parseable output ---------------===//
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

#include "swift/Driver/ParseableOutput.h"

#include "swift/Basic/JSONSerialization.h"
#include "swift/Basic/Statistic.h"
#include "swift/Driver/Action.h"
#include "swift/Driver/Job.h"
#include "swift/Driver/Types.h"
#include "llvm/Option/Arg.h"
#include "llvm/Support/Chrono.h"
#include "llvm/Support/raw_ostream.h"

using namespace swift::driver::parseable_output;
using namespace swift::driver;
using namespace swift;

namespace {
  struct CommandInput {
    std::string Path;
    CommandInput() {}
    CommandInput(StringRef Path) : Path(Path) {}
  };

  typedef std::pair<types::ID, std::string> OutputPair;
} // end anonymous namespace

namespace swift {
namespace json {
  template<>
  struct ScalarTraits<CommandInput> {
    static void output(const CommandInput &value, llvm::raw_ostream &os) {
      os << value.Path;
    }
    static bool mustQuote(StringRef) { return true; }
  };

  template<>
  struct ScalarEnumerationTraits<types::ID> {
    static void enumeration(Output &out, types::ID &value) {
      types::forAllTypes([&](types::ID ty) {
        std::string typeName = types::getTypeName(ty);
        out.enumCase(value, typeName.c_str(), ty);
      });
    }
  };

  template<>
  struct ObjectTraits<std::pair<types::ID, std::string>> {
    static void mapping(Output &out, std::pair<types::ID, std::string> &value) {
      out.mapRequired("type", value.first);
      out.mapRequired("path", value.second);
    }
  };

  template<typename T, unsigned N>
  struct ArrayTraits<SmallVector<T, N>> {
    static size_t size(Output &out, SmallVector<T, N> &seq) {
      return seq.size();
    }

    static T &element(Output &out, SmallVector<T, N> &seq, size_t index) {
      if (index >= seq.size())
        seq.resize(index+1);
      return seq[index];
    }
  };

  template<>
  struct ScalarTraits<llvm::sys::TimePoint<>> {
    static void output(const llvm::sys::TimePoint<> &value, llvm::raw_ostream &os) {
      using namespace std::chrono;
      os << duration_cast<microseconds>(value.time_since_epoch()).count();
    }
    static bool mustQuote(StringRef) { return false; }
  };

} // namespace json
} // namespace swift

namespace {

class Message {
  std::string Kind;
  std::string Name;
  llvm::sys::TimePoint<> Timestamp;
  Optional<ResourceStats> Resources;
public:
  Message(StringRef Kind, StringRef Name,
          Optional<ResourceStats> Resources = Optional<ResourceStats>()) :
    Kind(Kind), Name(Name),
    Timestamp(std::chrono::system_clock::now()),
    Resources(Resources) {}
  virtual ~Message() = default;

  virtual void provideMapping(swift::json::Output &out) {
    out.mapRequired("kind", Kind);
    out.mapRequired("name", Name);
    out.mapRequired("timestamp", Timestamp);
    out.mapOptional("resources", Resources);
  }
};

class CommandBasedMessage : public Message {
public:
  CommandBasedMessage(StringRef Kind, const Job &Cmd,
                      Optional<ResourceStats> Resources =
                      Optional<ResourceStats>()) :
    Message(Kind, Cmd.getSource().getClassName(), Resources) {}
};

class DetailedCommandBasedMessage : public CommandBasedMessage {
  std::string CommandLine;
  SmallVector<CommandInput, 4> Inputs;
  SmallVector<OutputPair, 8> Outputs;
public:
  DetailedCommandBasedMessage(StringRef Kind, const Job &Cmd) :
      CommandBasedMessage(Kind, Cmd) {
    llvm::raw_string_ostream wrapper(CommandLine);
    Cmd.printCommandLine(wrapper, "");
    wrapper.flush();

    for (const Action *A : Cmd.getSource().getInputs()) {
      if (const InputAction *IA = dyn_cast<InputAction>(A))
        Inputs.push_back(CommandInput(IA->getInputArg().getValue()));
    }

    for (const Job *J : Cmd.getInputs()) {
      ArrayRef<std::string> OutFiles = J->getOutput().getPrimaryOutputFilenames();
      if (const auto *BJAction = dyn_cast<BackendJobAction>(&Cmd.getSource())) {
        Inputs.push_back(CommandInput(OutFiles[BJAction->getInputIndex()]));
      } else {
        for (const std::string &FileName : OutFiles) {
          Inputs.push_back(CommandInput(FileName));
        }
      }
    }

    // TODO: set up Outputs appropriately.
    types::ID PrimaryOutputType = Cmd.getOutput().getPrimaryOutputType();
    if (PrimaryOutputType != types::TY_Nothing) {
      for (const std::string &OutputFileName : Cmd.getOutput().
                                                 getPrimaryOutputFilenames()) {
        Outputs.push_back(OutputPair(PrimaryOutputType, OutputFileName));
      }
    }
    types::forAllTypes([&](types::ID Ty) {
      const std::string &Output =
          Cmd.getOutput().getAdditionalOutputForType(Ty);
      if (!Output.empty())
        Outputs.push_back(OutputPair(Ty, Output));
    });
  }

  void provideMapping(swift::json::Output &out) override {
    Message::provideMapping(out);
    out.mapRequired("command", CommandLine);
    out.mapOptional("inputs", Inputs);
    out.mapOptional("outputs", Outputs);
  }
};

class TaskBasedMessage : public CommandBasedMessage {
  ProcessId Pid;
public:
  TaskBasedMessage(StringRef Kind, const Job &Cmd, ProcessId Pid,
                   Optional<ResourceStats> Resources) :
    CommandBasedMessage(Kind, Cmd, Resources), Pid(Pid) {}

  void provideMapping(swift::json::Output &out) override {
    CommandBasedMessage::provideMapping(out);
    out.mapRequired("pid", Pid);
  }
};

class BeganMessage : public DetailedCommandBasedMessage {
  ProcessId Pid;
public:
  BeganMessage(const Job &Cmd, ProcessId Pid) :
      DetailedCommandBasedMessage("began", Cmd), Pid(Pid) {}

  void provideMapping(swift::json::Output &out) override {
    DetailedCommandBasedMessage::provideMapping(out);
    out.mapRequired("pid", Pid);
  }
};

class TaskOutputMessage : public TaskBasedMessage {
  std::string Output;
public:
  TaskOutputMessage(StringRef Kind, const Job &Cmd, ProcessId Pid,
                    StringRef Output,
                    Optional<ResourceStats> Resources)
    : TaskBasedMessage(Kind, Cmd, Pid, Resources), Output(Output) {}

  void provideMapping(swift::json::Output &out) override {
    TaskBasedMessage::provideMapping(out);
    out.mapOptional("output", Output, std::string());
  }
};

class FinishedMessage : public TaskOutputMessage {
  int ExitStatus;
public:
  FinishedMessage(const Job &Cmd, ProcessId Pid, StringRef Output,
                  int ExitStatus, Optional<ResourceStats> Resources) :
    TaskOutputMessage("finished", Cmd, Pid, Output, Resources),
    ExitStatus(ExitStatus) {}

  void provideMapping(swift::json::Output &out) override {
    TaskOutputMessage::provideMapping(out);
    out.mapRequired("exit-status", ExitStatus);
  }
};

class SignalledMessage : public TaskOutputMessage {
  std::string ErrorMsg;
  Optional<int> Signal;
public:
  SignalledMessage(const Job &Cmd, ProcessId Pid, StringRef Output,
                   StringRef ErrorMsg, Optional<int> Signal,
                   Optional<ResourceStats> Resources) :
    TaskOutputMessage("signalled", Cmd, Pid, Output, Resources),
    ErrorMsg(ErrorMsg), Signal(Signal) {}

  void provideMapping(swift::json::Output &out) override {
    TaskOutputMessage::provideMapping(out);
    out.mapOptional("error-message", ErrorMsg, std::string());
    out.mapOptional("signal", Signal);
  }
};

class SkippedMessage : public DetailedCommandBasedMessage {
public:
  SkippedMessage(const Job &Cmd) :
      DetailedCommandBasedMessage("skipped", Cmd) {}
};

class CompilationMessage : public Message {
  CompilationCounters Counters;
  public:
  CompilationMessage(StringRef Name, const CompilationCounters &Counters,
                     Optional<ResourceStats> Resources) :
    Message("compilation", Name, Resources),
    Counters(Counters) {}

  void provideMapping(swift::json::Output &out) override {
    Message::provideMapping(out);
    out.mapRequired("counters", Counters);
  }
};

} // end anonymous namespace

namespace swift {
namespace json {

template<>
struct ObjectTraits<Message> {
  static void mapping(Output &out, Message &msg) {
    msg.provideMapping(out);
  }
};

template<>
struct ObjectTraits<ResourceStats> {
  static void mapping(Output &out, ResourceStats &RS) {
    out.mapRequired("user", RS.UserTimeUsec);
    out.mapRequired("sys", RS.SystemTimeUsec);
    out.mapRequired("rss", RS.MaxResidentBytes);
  }
};

template<>
struct ObjectTraits<CompilationCounters> {
  static void mapping(Output &out, CompilationCounters &C) {
    out.mapRequired("jobs-total", C.JobsTotal);
    out.mapRequired("jobs-skipped", C.JobsSkipped);
    out.mapRequired("dep-cascading-top-level", C.DepCascadingTopLevel);
    out.mapRequired("dep-cascading-dynamic", C.DepCascadingDynamic);
    out.mapRequired("dep-cascading-nominal", C.DepCascadingNominal);
    out.mapRequired("dep-cascading-member", C.DepCascadingMember);
    out.mapRequired("dep-cascading-external", C.DepCascadingExternal);
    out.mapRequired("dep-top-level", C.DepTopLevel);
    out.mapRequired("dep-dynamic", C.DepDynamic);
    out.mapRequired("dep-nominal", C.DepNominal);
    out.mapRequired("dep-member", C.DepMember);
    out.mapRequired("dep-external", C.DepExternal);
  }
};

} // namespace json
} // namespace swift

static void emitMessage(raw_ostream &os, Message &msg) {
  std::string JSONString;
  llvm::raw_string_ostream BufferStream(JSONString);
  json::Output yout(BufferStream);
  yout << msg;
  BufferStream.flush();
  os << JSONString.length() << '\n';
  os << JSONString << '\n';
}

void parseable_output::emitBeganMessage(raw_ostream &os,
                                        const Job &Cmd, ProcessId Pid) {
  BeganMessage msg(Cmd, Pid);
  emitMessage(os, msg);
}

void parseable_output::emitFinishedMessage(raw_ostream &os,
                                           const Job &Cmd, ProcessId Pid,
                                           int ExitStatus, StringRef Output,
                                           Optional<ResourceStats> Resources) {
  FinishedMessage msg(Cmd, Pid, Output, ExitStatus, Resources);
  emitMessage(os, msg);
}

void parseable_output::emitSignalledMessage(raw_ostream &os,
                                            const Job &Cmd, ProcessId Pid,
                                            StringRef ErrorMsg,
                                            StringRef Output,
                                            Optional<int> Signal,
                                            Optional<ResourceStats> Resources) {
  SignalledMessage msg(Cmd, Pid, Output, ErrorMsg, Signal, Resources);
  emitMessage(os, msg);
}

void parseable_output::emitSkippedMessage(raw_ostream &os, const Job &Cmd) {
  SkippedMessage msg(Cmd);
  emitMessage(os, msg);
}

void parseable_output::emitCompilationMessage(raw_ostream &os, StringRef Name,
                                              const CompilationCounters &Counters,
                                              Optional<ResourceStats> Resources) {
  CompilationMessage msg(Name, Counters, Resources);
  emitMessage(os, msg);
}
