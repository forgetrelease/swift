// This source file is part of the Swift.org open source project
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

// RUN: not %target-swift-frontend %s -emit-ir

// REQUIRES: deterministic-compiler
// see https://bugs.swift.org/browse/SR-4894
struct A:RangeReplaceableCollection{let c{{a f{}}var f=max
