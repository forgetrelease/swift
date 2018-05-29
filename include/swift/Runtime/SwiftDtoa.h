//===--- SwiftDtoa.h ---------------------------------------------*- c -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===---------------------------------------------------------------------===//

#ifndef SWIFT_DTOA_H
#define SWIFT_DTOA_H

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

// This implementation strongly assumes that `float` is
// IEEE 754 single-precision binary32 format and that
// `double` is IEEE 754 double-precision binary64 format.

// Essentially all modern platforms use IEEE 754 floating point
// types now, so enable these by default:
#define SWIFT_DTOA_FLOAT_SUPPORT 1
#define SWIFT_DTOA_DOUBLE_SUPPORT 1

// This implementation assumes `long double` is Intel 80-bit extended format.
#if defined(_WIN32)
 // Windows has `long double` == `double` on all platforms, so disable this.
 #undef SWIFT_DTOA_FLOAT80_SUPPORT
#elif defined(__APPLE__) || defined(__linux__)
 // macOS and Linux support Float80 on X86 hardware but not on ARM
 #if defined(__x86_64__) || defined(__i386)
  #define SWIFT_DTOA_FLOAT80_SUPPORT 1
 #endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

#if SWIFT_DTOA_DOUBLE_SUPPORT
// Compute the optimal decimal digits and exponent for a double.
//
// Input:
// * `d` is the number to be decomposed
// * `digits` is an array of `digits_length`
// * `decimalExponent` is a pointer to an `int`
//
// Ouput:
// * `digits` will receive the decimal digits
// * `decimalExponent` will receive the decimal exponent
// * function returns the number of digits generated
// * the sign of the input number is ignored
//
// Guarantees:
//
// * Accurate. If you parse the result back to a double via an accurate
//   algorithm (such as Clinger's algorithm), the resulting double will
//   be exactly equal to the original value.  On most systems, this
//   implies that using `strtod` to parse the output of
//   `swift_format_double` will yield exactly the original value.
//
// * Short. No other accurate result will have fewer digits.
//
// * Close. If there are multiple possible decimal forms that are
//   both accurate and short, the form computed here will be
//   closest to the original binary value.
//
// Notes:
//
// If the input value is infinity or NaN, or `digits_length < 17`, the
// function returns zero and generates no ouput.
//
// If the input value is zero, it will return `decimalExponent = 0` and
// a single digit of value zero.
//
int swift_decompose_double(double d,
    int8_t *digits, size_t digits_length, int *decimalExponent);

// Format a double as an ASCII string.
//
// For infinity, it outputs "inf" or "-inf".
//
// For NaN, it outputs a Swift-style detailed dump, including
// sign, signaling/quiet, and payload (if any).  Typical output:
// "nan", "-nan", "-snan(0x1234)".
//
// For zero, it outputs "0.0" or "-0.0" depending on the sign.
//
// For other values, it uses `swift_decompose_double` to compute the
// digits, then uses either `swift_format_decimal` or
// `swift_format_exponential` to produce an ASCII string depending on
// the magnitude of the value.
//
// In all cases, it returns the number of ASCII characters actually
// written, or zero if the buffer was too small.
size_t swift_format_double(double, char *dest, size_t length);
#endif

#if SWIFT_DTOA_FLOAT_SUPPORT
// See swift_decompose_double.  `digits_length` must be at least 9.
int swift_decompose_float(float f,
    int8_t *digits, size_t digits_length, int *decimalExponent);
// See swift_format_double.
size_t swift_format_float(float, char *dest, size_t length);
#endif

#if SWIFT_DTOA_FLOAT80_SUPPORT
// See swift_decompose_double.  `digits_length` must be at least 21.
int swift_decompose_float80(long double f,
    int8_t *digits, size_t digits_length, int *decimalExponent);
// See swift_format_double.
size_t swift_format_float80(long double, char *dest, size_t length);
#endif

// Generate an ASCII string from the raw exponent and digit information
// as generated by `swift_decompose_double`.  Returns the number of
// bytes actually used.  If `dest` was not big enough, these functions
// return zero.  The generated string is always terminated with a zero
// byte unless `length` was zero.

// "Exponential" form uses common exponential format, e.g., "-1.234e+56"
// The exponent always has a sign and at least two digits.  The
// generated string is never longer than `digits_count + 9` bytes,
// including the trailing zero byte.
size_t swift_format_exponential(char *dest, size_t length,
    bool negative, const int8_t *digits, int digits_count, int decimalExponent);

// "Decimal" form writes the value without using exponents.  This
// includes cases such as "0.000001234", "123.456", and "123456000.0".
// Note that the result always has a decimal point with at least one
// digit before and one digit after.  The generated string is never
// longer than `digits_count + abs(exponent) + 4` bytes, including the
// trailing zero byte.
size_t swift_format_decimal(char *dest, size_t length,
    bool negative, const int8_t *digits, int digits_count, int decimalExponent);

#ifdef __cplusplus
}
#endif
#endif
