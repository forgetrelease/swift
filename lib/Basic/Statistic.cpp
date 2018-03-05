//===--- Statistic.cpp - Swift unified stats reporting --------------------===//
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

#include "clang/AST/Decl.h"
#include "clang/Basic/SourceLocation.h"
#include "clang/Basic/SourceManager.h"
#include "swift/Basic/Statistic.h"
#include "swift/Basic/Timer.h"
#include "swift/AST/Decl.h"
#include "swift/AST/Expr.h"
#include "swift/SIL/SILFunction.h"
#include "swift/Driver/DependencyGraph.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/Config/config.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/Process.h"
#include "llvm/Support/raw_ostream.h"
#include <chrono>
#include <limits>

#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#ifdef HAVE_SYS_RESOURCE_H
#include <sys/resource.h>
#endif

namespace swift {
using namespace llvm;
using namespace llvm::sys;

static int64_t
getChildrenMaxResidentSetSize() {
#if defined(HAVE_GETRUSAGE) && !defined(__HAIKU__)
  struct rusage RU;
  ::getrusage(RUSAGE_CHILDREN, &RU);
  int64_t M = static_cast<int64_t>(RU.ru_maxrss);
  if (M < 0)
    M = std::numeric_limits<int64_t>::max();
  return M;
#else
  return 0;
#endif
}

static std::string
makeFileName(StringRef Prefix,
             StringRef ProgramName,
             StringRef AuxName,
             StringRef Suffix) {
  std::string tmp;
  raw_string_ostream stream(tmp);
  auto now = std::chrono::system_clock::now();
  auto dur = now.time_since_epoch();
  auto usec = std::chrono::duration_cast<std::chrono::microseconds>(dur);
  stream << Prefix
         << "-" << usec.count()
         << "-" << ProgramName
         << "-" << AuxName
         << "-" << Process::GetRandomNumber()
         << "." << Suffix;
  return stream.str();
}

static std::string
makeStatsFileName(StringRef ProgramName,
                  StringRef AuxName) {
  return makeFileName("stats", ProgramName, AuxName, "json");
}

static std::string
makeTraceFileName(StringRef ProgramName,
                  StringRef AuxName) {
  return makeFileName("trace", ProgramName, AuxName, "csv");
}

static std::string
makeProfileDirName(StringRef ProgramName,
                   StringRef AuxName) {
  return makeFileName("profile", ProgramName, AuxName, "dir");
}

// LLVM's statistics-reporting machinery is sensitive to filenames containing
// YAML-quote-requiring characters, which occur surprisingly often in the wild;
// we only need a recognizable and likely-unique name for a target here, not an
// exact filename, so we go with a crude approximation. Furthermore, to avoid
// parse ambiguities when "demangling" counters and filenames we exclude hyphens
// and slashes.
static std::string
cleanName(StringRef n) {
  std::string tmp;
  for (auto c : n) {
    if (('a' <= c && c <= 'z') ||
        ('A' <= c && c <= 'Z') ||
        ('0' <= c && c <= '9') ||
        (c == '.'))
      tmp += c;
    else
      tmp += '_';
  }
  return tmp;
}

static std::string
auxName(StringRef ModuleName,
        StringRef InputName,
        StringRef TripleName,
        StringRef OutputType,
        StringRef OptType) {
  if (InputName.empty()) {
    InputName = "all";
  }
  // Dispose of path prefix, which might make composite name too long.
  InputName = path::filename(InputName);
  if (OptType.empty()) {
    OptType = "Onone";
  }
  if (!OutputType.empty() && OutputType.front() == '.') {
    OutputType = OutputType.substr(1);
  }
  if (!OptType.empty() && OptType.front() == '-') {
    OptType = OptType.substr(1);
  }
  return (cleanName(ModuleName)
          + "-" + cleanName(InputName)
          + "-" + cleanName(TripleName)
          + "-" + cleanName(OutputType)
          + "-" + cleanName(OptType));
}

class UnifiedStatsReporter::RecursionSafeTimers {

  struct RecursionSafeTimer {
    llvm::Optional<SharedTimer> Timer;
    size_t RecursionDepth;
  };

  StringMap<RecursionSafeTimer> Timers;

public:

  void beginTimer(StringRef Name) {
    RecursionSafeTimer &T = Timers[Name];
    if (T.RecursionDepth == 0) {
      T.Timer.emplace(Name);
    }
    T.RecursionDepth++;
  }

  void endTimer(StringRef Name) {
    auto I = Timers.find(Name);
    assert(I != Timers.end());
    RecursionSafeTimer &T = I->getValue();
    assert(T.RecursionDepth != 0);
    T.RecursionDepth--;
    if (T.RecursionDepth == 0) {
      T.Timer.reset();
    }
  }
};

class StatsProfiler {
  struct Node {
    int64_t SelfCount;
    typedef std::tuple<StringRef,
                       const void*,
                       const UnifiedStatsReporter::TraceFormatter*> Key;
    Node *Parent;
    DenseMap<Key, std::unique_ptr<Node>> Children;

    Node(Node *P=nullptr) : SelfCount(0), Parent(P)
    {}

    void print(std::vector<Key> &Context, raw_ostream &OS) const {
      StringRef delim;
      if (!(SelfCount == 0 || Context.empty())) {
        for (auto const &K : Context) {
          StringRef Name;
          const void* Entity;
          const UnifiedStatsReporter::TraceFormatter *Formatter;
          std::tie(Name, Entity, Formatter) = K;
          OS << delim << Name;
          if (Formatter && Entity) {
            OS << ' ';
            Formatter->traceName(Entity, OS);
          }
          delim = ";";
        }
        OS << ' ' << SelfCount << '\n';
      }
      for (auto const &I : Children) {
        Context.push_back(I.getFirst());
        I.getSecond()->print(Context, OS);
        Context.pop_back();
      }
    }

    Node *getChild(StringRef Name,
                   const void *Entity,
                   const UnifiedStatsReporter::TraceFormatter *TF) {
      Key K(Name, Entity, TF);
      auto I = Children.find(K);
      if (I != Children.end()) {
        return I->getSecond().get();
      } else {
        auto N = llvm::make_unique<Node>(this);
        auto P = N.get();
        Children.insert(std::make_pair(K, std::move(N)));
        return P;
      }
    }
  };
  Node Root;
  Node *Curr;
public:

  StatsProfiler()
    : Curr(&Root)
  {}
  StatsProfiler(StatsProfiler const &Other) = delete;
  StatsProfiler& operator=(const StatsProfiler&) = delete;

  void print(raw_ostream &OS) const {
    std::vector<Node::Key> Context;
    Root.print(Context, OS);
  }

  void printToFile(StringRef Dirname, StringRef Filename) const {
    SmallString<256> Path(Dirname);
    llvm::sys::path::append(Path, Filename);
    std::error_code EC;
    raw_fd_ostream Stream(Path, EC, fs::F_Append | fs::F_Text);
    if (EC) {
      llvm::errs() << "Error opening profile file '"
                   << Path << "' for writing\n";
      return;
    }
    print(Stream);
  }

  void profileEvent(StringRef Name,
                    double DeltaSeconds,
                    bool IsEntry,
                    const void *Entity=nullptr,
                    const UnifiedStatsReporter::TraceFormatter *TF=nullptr) {
    int64_t DeltaUSec = int64_t(1000000.0 * DeltaSeconds);
    profileEvent(Name, DeltaUSec, IsEntry, Entity, TF);
  }

  void profileEvent(StringRef Name,
                    int64_t Delta,
                    bool IsEntry,
                    const void *Entity=nullptr,
                    const UnifiedStatsReporter::TraceFormatter *TF=nullptr) {
    assert(Curr);
    Curr->SelfCount += Delta;
    if (IsEntry) {
      Node *Child = Curr->getChild(Name, Entity, TF);
      assert(Child);
      assert(Child->Parent == Curr);
      Curr = Child;
    } else {
      Curr = Curr->Parent;
      assert(Curr);
    }
  }
};

struct UnifiedStatsReporter::StatsProfilers
{
  // Timerecord of last update.
  llvm::TimeRecord LastUpdated;

  // One profiler for each time category.
  StatsProfiler UserTime;
  StatsProfiler SystemTime;
  StatsProfiler ProcessTime;
  StatsProfiler WallTime;

  // Then one profiler for each frontend statistic.
#define FRONTEND_STATISTIC(TY, NAME) StatsProfiler NAME;
#include "swift/Basic/Statistics.def"
#undef FRONTEND_STATISTIC

  StatsProfilers()
    : LastUpdated(llvm::TimeRecord::getCurrentTime())
  {}
};

UnifiedStatsReporter::UnifiedStatsReporter(StringRef ProgramName,
                                           StringRef ModuleName,
                                           StringRef InputName,
                                           StringRef TripleName,
                                           StringRef OutputType,
                                           StringRef OptType,
                                           StringRef Directory,
                                           SourceManager *SM,
                                           clang::SourceManager *CSM,
                                           bool TraceEvents,
                                           bool ProfileEvents,
                                           bool ProfileEntities)
  : UnifiedStatsReporter(ProgramName,
                         auxName(ModuleName,
                                 InputName,
                                 TripleName,
                                 OutputType,
                                 OptType),
                         Directory,
                         SM, CSM,
                         TraceEvents, ProfileEvents, ProfileEntities)
{
}

UnifiedStatsReporter::UnifiedStatsReporter(StringRef ProgramName,
                                           StringRef AuxName,
                                           StringRef Directory,
                                           SourceManager *SM,
                                           clang::SourceManager *CSM,
                                           bool TraceEvents,
                                           bool ProfileEvents,
                                           bool ProfileEntities)
  : currentProcessExitStatusSet(false),
    currentProcessExitStatus(EXIT_FAILURE),
    StatsFilename(Directory),
    TraceFilename(Directory),
    ProfileDirname(Directory),
    StartedTime(llvm::TimeRecord::getCurrentTime()),
    Timer(make_unique<NamedRegionTimer>(AuxName,
                                        "Building Target",
                                        ProgramName, "Running Program")),
    SourceMgr(SM),
    ClangSourceMgr(CSM),
    RecursiveTimers(llvm::make_unique<RecursionSafeTimers>())
{
  path::append(StatsFilename, makeStatsFileName(ProgramName, AuxName));
  path::append(TraceFilename, makeTraceFileName(ProgramName, AuxName));
  path::append(ProfileDirname, makeProfileDirName(ProgramName, AuxName));
  EnableStatistics(/*PrintOnExit=*/false);
  SharedTimer::enableCompilationTimers();
  if (TraceEvents || ProfileEvents || ProfileEntities)
    LastTracedFrontendCounters.emplace();
  if (TraceEvents)
    FrontendStatsEvents.emplace();
  if (ProfileEvents)
    EventProfilers = make_unique<StatsProfilers>();
  if (ProfileEntities)
    EntityProfilers = make_unique<StatsProfilers>();
}

UnifiedStatsReporter::AlwaysOnDriverCounters &
UnifiedStatsReporter::getDriverCounters()
{
  if (!DriverCounters)
    DriverCounters.emplace();
  return *DriverCounters;
}

UnifiedStatsReporter::AlwaysOnFrontendCounters &
UnifiedStatsReporter::getFrontendCounters()
{
  if (!FrontendCounters)
    FrontendCounters.emplace();
  return *FrontendCounters;
}

void
UnifiedStatsReporter::noteCurrentProcessExitStatus(int status) {
  assert(!currentProcessExitStatusSet);
  currentProcessExitStatusSet = true;
  currentProcessExitStatus = status;
}

void
UnifiedStatsReporter::publishAlwaysOnStatsToLLVM() {
  if (FrontendCounters) {
    auto &C = getFrontendCounters();
#define FRONTEND_STATISTIC(TY, NAME)                            \
    do {                                                        \
      static Statistic Stat = {#TY, #NAME, #NAME, {0}, false};  \
      Stat += (C).NAME;                                         \
    } while (0);
#include "swift/Basic/Statistics.def"
#undef FRONTEND_STATISTIC
  }
  if (DriverCounters) {
    auto &C = getDriverCounters();
#define DRIVER_STATISTIC(NAME)                                       \
    do {                                                             \
      static Statistic Stat = {"Driver", #NAME, #NAME, {0}, false};  \
      Stat += (C).NAME;                                              \
    } while (0);
#include "swift/Basic/Statistics.def"
#undef DRIVER_STATISTIC
  }
}

void
UnifiedStatsReporter::printAlwaysOnStatsAndTimers(raw_ostream &OS) {
  // Adapted from llvm::PrintStatisticsJSON
  OS << "{\n";
  const char *delim = "";
  if (FrontendCounters) {
    auto &C = getFrontendCounters();
#define FRONTEND_STATISTIC(TY, NAME)                        \
    do {                                                    \
      OS << delim << "\t\"" #TY "." #NAME "\": " << C.NAME; \
      delim = ",\n";                                        \
    } while (0);
#include "swift/Basic/Statistics.def"
#undef FRONTEND_STATISTIC
  }
  if (DriverCounters) {
    auto &C = getDriverCounters();
#define DRIVER_STATISTIC(NAME)                              \
    do {                                                    \
      OS << delim << "\t\"Driver." #NAME "\": " << C.NAME;  \
      delim = ",\n";                                        \
    } while (0);
#include "swift/Basic/Statistics.def"
#undef DRIVER_STATISTIC
  }
  // Print timers.
  TimerGroup::printAllJSONValues(OS, delim);
  OS << "\n}\n";
  OS.flush();
}

FrontendStatsTracer::FrontendStatsTracer(
    UnifiedStatsReporter *Reporter, StringRef EventName, const void *Entity,
    const UnifiedStatsReporter::TraceFormatter *Formatter)
    : Reporter(Reporter), SavedTime(), EventName(EventName), Entity(Entity),
      Formatter(Formatter) {
  if (Reporter) {
    SavedTime = llvm::TimeRecord::getCurrentTime();
    Reporter->saveAnyFrontendStatsEvents(*this, true);
  }
}

FrontendStatsTracer::FrontendStatsTracer() = default;

FrontendStatsTracer::FrontendStatsTracer(UnifiedStatsReporter *R, StringRef S)
    : FrontendStatsTracer(R, S, nullptr, nullptr)
{}

FrontendStatsTracer::FrontendStatsTracer(UnifiedStatsReporter *R, StringRef S,
                                         const Decl *D)
    : FrontendStatsTracer(R, S, D, getTraceFormatter<const Decl *>())
{}

FrontendStatsTracer::FrontendStatsTracer(UnifiedStatsReporter *R, StringRef S,
                                         const ProtocolConformance *P)
    : FrontendStatsTracer(R, S, P,
                          getTraceFormatter<const ProtocolConformance *>()) {}

FrontendStatsTracer::FrontendStatsTracer(UnifiedStatsReporter *R, StringRef S,
                                         const Expr *E)
    : FrontendStatsTracer(R, S, E, getTraceFormatter<const Expr *>())
{}

FrontendStatsTracer::FrontendStatsTracer(UnifiedStatsReporter *R, StringRef S,
                                         const clang::Decl *D)
    : FrontendStatsTracer(R, S, D, getTraceFormatter<const clang::Decl *>())
{}

FrontendStatsTracer::FrontendStatsTracer(UnifiedStatsReporter *R, StringRef S,
                                         const SILFunction *F)
    : FrontendStatsTracer(R, S, F, getTraceFormatter<const SILFunction *>())
{}

FrontendStatsTracer&
FrontendStatsTracer::operator=(FrontendStatsTracer&& other)
{
  Reporter = other.Reporter;
  SavedTime = other.SavedTime;
  EventName = other.EventName;
  Entity = other.Entity;
  Formatter = other.Formatter;
  other.Reporter = nullptr;
  return *this;
}

FrontendStatsTracer::FrontendStatsTracer(FrontendStatsTracer&& other)
  : Reporter(other.Reporter),
    SavedTime(other.SavedTime),
    EventName(other.EventName),
    Entity(other.Entity),
    Formatter(other.Formatter)
{
  other.Reporter = nullptr;
}

FrontendStatsTracer::~FrontendStatsTracer()
{
  if (Reporter)
    Reporter->saveAnyFrontendStatsEvents(*this, false);
}

static inline void
saveEvent(StringRef StatName,
          int64_t Curr, int64_t Last,
          uint64_t NowUS, uint64_t LiveUS,
          std::vector<UnifiedStatsReporter::FrontendStatsEvent> &Events,
          FrontendStatsTracer const& T,
          bool IsEntry) {
  int64_t Delta = Curr - Last;
  if (Delta != 0) {
    Events.emplace_back(UnifiedStatsReporter::FrontendStatsEvent{
        NowUS, LiveUS, IsEntry, T.EventName, StatName, Delta, Curr,
        T.Entity, T.Formatter});
  }
}

void
UnifiedStatsReporter::saveAnyFrontendStatsEvents(
    FrontendStatsTracer const& T,
    bool IsEntry)
{
  // First make a note in the recursion-safe timers; these
  // are active anytime UnifiedStatsReporter is active.
  if (IsEntry) {
    RecursiveTimers->beginTimer(T.EventName);
  } else {
    RecursiveTimers->endTimer(T.EventName);
  }

  // If we don't have a saved entry to form deltas against in the trace buffer
  // or profilers, we're not tracing or profiling: return early.
  if (!LastTracedFrontendCounters)
    return;
  auto Now = llvm::TimeRecord::getCurrentTime();
  auto &Curr = getFrontendCounters();
  auto &Last = *LastTracedFrontendCounters;
  if (EventProfilers) {
    auto TimeDelta = Now;
    TimeDelta -= EventProfilers->LastUpdated;
    EventProfilers->UserTime.profileEvent(T.EventName,
                                          TimeDelta.getUserTime(),
                                          IsEntry);
    EventProfilers->SystemTime.profileEvent(T.EventName,
                                            TimeDelta.getSystemTime(),
                                            IsEntry);
    EventProfilers->ProcessTime.profileEvent(T.EventName,
                                             TimeDelta.getProcessTime(),
                                             IsEntry);
    EventProfilers->WallTime.profileEvent(T.EventName,
                                          TimeDelta.getWallTime(),
                                          IsEntry);
#define FRONTEND_STATISTIC(TY, N)                                       \
    EventProfilers->N.profileEvent(T.EventName, Curr.N - Last.N, IsEntry);
#include "swift/Basic/Statistics.def"
#undef FRONTEND_STATISTIC
    EventProfilers->LastUpdated = Now;
  }

  if (EntityProfilers) {
    auto TimeDelta = Now;
    TimeDelta -= EntityProfilers->LastUpdated;
    EntityProfilers->UserTime.profileEvent(T.EventName,
                                           TimeDelta.getUserTime(),
                                           IsEntry, T.Entity, T.Formatter);
    EntityProfilers->SystemTime.profileEvent(T.EventName,
                                             TimeDelta.getSystemTime(),
                                             IsEntry, T.Entity, T.Formatter);
    EntityProfilers->ProcessTime.profileEvent(T.EventName,
                                              TimeDelta.getProcessTime(),
                                              IsEntry, T.Entity, T.Formatter);
    EntityProfilers->WallTime.profileEvent(T.EventName,
                                           TimeDelta.getWallTime(),
                                           IsEntry, T.Entity, T.Formatter);
#define FRONTEND_STATISTIC(TY, N)                                          \
    EntityProfilers->N.profileEvent(T.EventName, Curr.N - Last.N, IsEntry, \
                                    T.Entity, T.Formatter);
#include "swift/Basic/Statistics.def"
#undef FRONTEND_STATISTIC
    EntityProfilers->LastUpdated = Now;
  }

  if (FrontendStatsEvents) {
    auto StartUS = uint64_t(1000000.0 * T.SavedTime.getProcessTime());
    auto NowUS = uint64_t(1000000.0 * Now.getProcessTime());
    auto LiveUS = IsEntry ? 0 : NowUS - StartUS;
    auto &Events = *FrontendStatsEvents;
#define FRONTEND_STATISTIC(TY, N)                                       \
    saveEvent(#TY "." #N, Curr.N, Last.N, NowUS, LiveUS, Events, T, IsEntry);
#include "swift/Basic/Statistics.def"
#undef FRONTEND_STATISTIC
  }

  // Save all counters (changed or otherwise).
  Last = Curr;
}

UnifiedStatsReporter::TraceFormatter::~TraceFormatter() {}

UnifiedStatsReporter::~UnifiedStatsReporter()
{
  // If nobody's marked this process as successful yet,
  // mark it as failing.
  if (currentProcessExitStatus != EXIT_SUCCESS) {
    if (FrontendCounters) {
      auto &C = getFrontendCounters();
      C.NumProcessFailures++;
    } else {
      auto &C = getDriverCounters();
      C.NumProcessFailures++;
    }
  }

  // NB: Timer needs to be Optional<> because it needs to be destructed early;
  // LLVM will complain about double-stopping a timer if you tear down a
  // NamedRegionTimer after printing all timers. The printing routines were
  // designed with more of a global-scope, run-at-process-exit in mind, which
  // we're repurposing a bit here.
  Timer.reset();

  // We currently do this by manual TimeRecord keeping because LLVM has decided
  // not to allow access to the Timers inside NamedRegionTimers.
  auto ElapsedTime = llvm::TimeRecord::getCurrentTime();
  ElapsedTime -= StartedTime;

  if (DriverCounters) {
    auto &C = getDriverCounters();
    C.ChildrenMaxRSS = getChildrenMaxResidentSetSize();
  }

  if (FrontendCounters) {
    auto &C = getFrontendCounters();
    // Convenience calculation for crude top-level "absolute speed".
    if (C.NumSourceLines != 0 && ElapsedTime.getProcessTime() != 0.0)
      C.NumSourceLinesPerSecond = (int64_t) (((double)C.NumSourceLines) /
                                             ElapsedTime.getProcessTime());
  }

  std::error_code EC;
  raw_fd_ostream ostream(StatsFilename, EC, fs::F_Append | fs::F_Text);
  if (EC) {
    llvm::errs() << "Error opening -stats-output-dir file '"
                 << TraceFilename << "' for writing\n";
    return;
  }

  // We change behavior here depending on whether -DLLVM_ENABLE_STATS and/or
  // assertions were on in this build; this is somewhat subtle, but turning on
  // all stats for all of LLVM and clang is a bit more expensive and intrusive
  // than we want to be in release builds.
  //
  //  - If enabled: we copy all of our "always-on" local stats into LLVM's
  //    global statistics list, and ask LLVM to manage the printing of them.
  //
  //  - If disabled: we still have our "always-on" local stats to write, and
  //    LLVM's global _timers_ were still enabled (they're runtime-enabled, not
  //    compile-time) so we sequence printing our own stats and LLVM's timers
  //    manually.

#if !defined(NDEBUG) || defined(LLVM_ENABLE_STATS)
  publishAlwaysOnStatsToLLVM();
  PrintStatisticsJSON(ostream);
#else
  printAlwaysOnStatsAndTimers(ostream);
#endif

  if (FrontendStatsEvents && SourceMgr) {
    std::error_code EC;
    raw_fd_ostream tstream(TraceFilename, EC, fs::F_Append | fs::F_Text);
    if (EC) {
      llvm::errs() << "Error opening -trace-stats-events file '"
                   << TraceFilename << "' for writing\n";
      return;
    }
    tstream << "Time,Live,IsEntry,EventName,CounterName,"
            << "CounterDelta,CounterValue,EntityName,EntityRange\n";
    for (auto const &E : *FrontendStatsEvents) {
      tstream << E.TimeUSec << ','
              << E.LiveUSec << ','
              << (E.IsEntry ? "\"entry\"," : "\"exit\",")
              << '"' << E.EventName << '"' << ','
              << '"' << E.CounterName << '"' << ','
              << E.CounterDelta << ','
              << E.CounterValue << ',';
      tstream << '"';
      if (E.Formatter)
        E.Formatter->traceName(E.Entity, tstream);
      tstream << '"' << ',';
      tstream << '"';
      if (E.Formatter)
        E.Formatter->traceLoc(E.Entity, SourceMgr, ClangSourceMgr, tstream);
      tstream << '"' << '\n';
    }
  }

  if (EventProfilers || EntityProfilers) {
    std::error_code EC = llvm::sys::fs::create_directories(ProfileDirname);
    if (EC) {
      llvm::errs() << "Failed to create directory '" << ProfileDirname << "': "
                   << EC.message() << "\n";
      return;
    }
    if (EventProfilers) {
      auto D = ProfileDirname;
      EventProfilers->UserTime.printToFile(D, "Time.User.events");
      EventProfilers->SystemTime.printToFile(D, "Time.System.events");
      EventProfilers->ProcessTime.printToFile(D, "Time.Process.events");
      EventProfilers->WallTime.printToFile(D, "Time.Wall.events");
#define FRONTEND_STATISTIC(TY, NAME)                                    \
      EventProfilers->NAME.printToFile(ProfileDirname,                  \
                                       #TY "." #NAME ".events");
#include "swift/Basic/Statistics.def"
#undef FRONTEND_STATISTIC
    }
    if (EntityProfilers) {
      auto D = ProfileDirname;
      EntityProfilers->UserTime.printToFile(D, "Time.User.entities");
      EntityProfilers->SystemTime.printToFile(D, "Time.System.entities");
      EntityProfilers->ProcessTime.printToFile(D, "Time.Process.entities");
      EntityProfilers->WallTime.printToFile(D, "Time.Wall.entities");
#define FRONTEND_STATISTIC(TY, NAME)                                    \
      EntityProfilers->NAME.printToFile(ProfileDirname,                 \
                                       #TY "." #NAME ".entities");
#include "swift/Basic/Statistics.def"
#undef FRONTEND_STATISTIC
    }
  }
}

} // namespace swift
