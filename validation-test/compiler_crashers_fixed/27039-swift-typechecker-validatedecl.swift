// This source file is part of the Swift.org open source project
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

// RUN: not %target-swift-frontend %s -typecheck
struct b{class A{{}enum a{enum a{class B{enum B}}}}enum S<T where H:A{struct Q{class B:b{{}}class b
