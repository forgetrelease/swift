//===--- Misc.c - Glibc overlay helpers -----------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include <fcntl.h>

extern "C" int
_swift_Glibc_fcntl(int fd, int cmd, int value) {
	return fcntl(fd, cmd, value);
}

extern "C" int
_swift_Glibc_fcntlPtr(int fd, int cmd, void* ptr) {
	return fcntl(fd, cmd, ptr);
}

