//===--- ImageInspectionMachO.cpp - Mach-O image inspection ---------------===//
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
///
/// \file
///
/// This file includes routines that interact with dyld on Mach-O-based
/// platforms to extract runtime metadata embedded in images generated by the
/// Swift compiler.
///
//===----------------------------------------------------------------------===//

#if defined(__APPLE__) && defined(__MACH__)

#include "ImageInspection.h"
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <assert.h>
#include <dlfcn.h>

using namespace swift;

namespace {
/// The Mach-O section name for the section containing protocol conformances.
/// This lives within SEG_TEXT.
constexpr const char ProtocolConformancesSection[] = "__swift5_proto";
/// The Mach-O section name for the section containing type references.
/// This lives within SEG_TEXT.
constexpr const char TypeMetadataRecordSection[] = "__swift5_types";

template<const char *SECTION_NAME,
         void CONSUME_BLOCK(const void *start, uintptr_t size)>
void addImageCallback(const mach_header *mh, intptr_t vmaddr_slide) {
#if __POINTER_WIDTH__ == 64
  using mach_header_platform = mach_header_64;
  assert(mh->magic == MH_MAGIC_64 && "loaded non-64-bit image?!");
#else
  using mach_header_platform = mach_header;
#endif
  
  // Look for a __swift5_proto section.
  unsigned long size;
  const uint8_t *section =
  getsectiondata(reinterpret_cast<const mach_header_platform *>(mh),
                 SEG_TEXT, SECTION_NAME,
                 &size);
  
  if (!section)
    return;
  
  CONSUME_BLOCK(section, size);
}

} // end anonymous namespace

void swift::initializeProtocolConformanceLookup() {
  _dyld_register_func_for_add_image(
    addImageCallback<ProtocolConformancesSection,
                     addImageProtocolConformanceBlockCallback>);
}
void swift::initializeTypeMetadataRecordLookup() {
  _dyld_register_func_for_add_image(
    addImageCallback<TypeMetadataRecordSection,
                     addImageTypeMetadataRecordBlockCallback>);
  
}

int swift::lookupSymbol(const void *address, SymbolInfo *info) {
  Dl_info dlinfo;
  if (dladdr(address, &dlinfo) == 0) {
    return 0;
  }

  info->fileName = dlinfo.dli_fname;
  info->baseAddress = dlinfo.dli_fbase;
  info->symbolName = dlinfo.dli_sname;
  info->symbolAddress = dlinfo.dli_saddr;
  return 1;
}

#endif // defined(__APPLE__) && defined(__MACH__)
