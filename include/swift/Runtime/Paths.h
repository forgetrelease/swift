//===--- Paths.h - Swift Runtime path utility functions ---------*- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Functions that obtain paths that might be useful within the runtime.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_RUNTIME_UTILS_H
#define SWIFT_RUNTIME_UTILS_H

#include "swift/Runtime/Config.h"

/// Return the path of the libswiftCore library.
///
/// This can be used to locate files that are installed alongside the
/// Swift runtime library.
///
/// \return A string containing the full path to libswiftCore.  The string
///         is owned by the runtime and should not be freed.
SWIFT_RUNTIME_EXPORT
const char *
swift_getRuntimePath();

/// Return the path of the Swift root.
///
/// If the path to libswiftCore is `/usr/local/swift/lib/libswiftCore.dylib`,
/// this function would return `/usr/local/swift`.
///
/// The path returned here can be overridden by setting the environment
/// variable SWIFT_ROOT.
///
/// \return A string containing the full path to the Swift root directory,
///         based either on the location of the Swift runtime, or on the
///         `SWIFT_ROOT` environment variable if set.
SWIFT_RUNTIME_EXPORT
const char *
swift_getRootPath();

/// Return the path of the specified auxiliary executable.
///
/// This function will return `/path/to/swift/root/libexec/<name>`, and on
/// Windows, it will automatically add `.exe` to the end.  (This means that
/// you don't need to special case the name for Windows.)
///
/// It does not test that the executable exists or that it is indeed
/// executable by the current user.  If you are using this function to locate
/// a utility program for use by the runtime, you should provide a way to
/// override its location using an environment variable.
///
/// \param name The name of the executable to locate.
///
/// \return A string containing the full path to the executable.
SWIFT_RUNTIME_EXPORT
const char *
swift_getAuxiliaryExecutablePath(const char *name);

#endif // SWIFT_RUNTIME_PATHS_H
