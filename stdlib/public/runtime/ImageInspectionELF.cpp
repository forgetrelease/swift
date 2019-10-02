//===--- ImageInspectionELF.cpp - ELF image inspection --------------------===//
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
/// This file includes routines that interact with ld*.so on ELF-based platforms
/// to extract runtime metadata embedded in dynamically linked ELF images
/// generated by the Swift compiler.
///
//===----------------------------------------------------------------------===//

#if defined(__ELF__)

#include "ImageInspection.h"
#include "ImageInspectionELF.h"
#include <dlfcn.h>

using namespace swift;

namespace {
static swift::MetadataSectionsList *registered = nullptr;

void record(swift::MetadataSectionsList *section_list) {
  if (registered == nullptr) {
    registered = section_list;
    section_list->next = section_list->prev = section_list;
  } else {
    registered->prev->next = section_list;
    section_list->next = registered;
    section_list->prev = registered->prev;
    registered->prev = section_list;
  }
}
}

void swift::initializeProtocolLookup() {
  const swift::MetadataSectionsList *sections_list = registered;
  while (true) {
    const swift::MetadataSections::Range &protocols =
        sections_list->sections->swift5_protocols;
    if (protocols.length())
      addImageProtocolsBlockCallbackUnsafe(
          protocols.start.get(), protocols.length());

    if (sections_list->next == registered)
      break;
    sections_list = sections_list->next;
  }
}
void swift::initializeProtocolConformanceLookup() {
  const swift::MetadataSectionsList *sections_list = registered;
  while (true) {
    const swift::MetadataSections::Range &conformances =
        sections_list->sections->swift5_protocol_conformances;
    if (conformances.length())
      addImageProtocolConformanceBlockCallbackUnsafe(
          conformances.start.get(), conformances.length());

    if (sections_list->next == registered)
      break;
    sections_list = sections_list->next;
  }
}

void swift::initializeTypeMetadataRecordLookup() {
  const swift::MetadataSectionsList *sections_list = registered;
  while (true) {
    const swift::MetadataSections::Range &type_metadata =
        sections_list->sections->swift5_type_metadata;
    if (type_metadata.length())
      addImageTypeMetadataRecordBlockCallbackUnsafe(
          type_metadata.start.get(), type_metadata.length());

    if (sections_list->next == registered)
      break;
    sections_list = sections_list->next;
  }
}

void swift::initializeDynamicReplacementLookup() {
}

// As ELF images are loaded, a global constructor will call
// addNewImage() with an address in the image that can be used to build
// a linked list of section directories for all of the currently loaded
// Swift images in the process.
SWIFT_RUNTIME_EXPORT
void swift::swift_addNewImage(MetadataSectionsList *node) {
  record(node);

  auto sections = node->sections;

  const auto &protocols_section = sections->swift5_protocols;
  const void *protocols = protocols_section.start.get();
  if (protocols_section.length())
    addImageProtocolsBlockCallback(protocols, protocols_section.length());

  const auto &protocol_conformances = sections->swift5_protocol_conformances;
  const void *conformances = protocol_conformances.start.get();
  if (protocol_conformances.length())
    addImageProtocolConformanceBlockCallback(conformances,
                                             protocol_conformances.length());

  const auto &type_metadata = sections->swift5_type_metadata;
  const void *metadata = type_metadata.start.get();
  if (type_metadata.length())
    addImageTypeMetadataRecordBlockCallback(metadata, type_metadata.length());

  const auto &dynamic_replacements = sections->swift5_replace;
  const auto *replacements = dynamic_replacements.start.get();
  if (dynamic_replacements.length()) {
    const auto &dynamic_replacements_some = sections->swift5_replac2;
    const auto *replacements_some = dynamic_replacements_some.start.get();
    addImageDynamicReplacementBlockCallback(
        replacements, dynamic_replacements.length(), replacements_some,
        dynamic_replacements_some.length());
  }
}

int swift::lookupSymbol(const void *address, SymbolInfo *info) {
  Dl_info dlinfo;
  if (dladdr(address, &dlinfo) == 0) {
    return 0;
  }

  info->fileName = dlinfo.dli_fname;
  info->baseAddress = dlinfo.dli_fbase;
  info->symbolName.reset(dlinfo.dli_sname);
  info->symbolAddress = dlinfo.dli_saddr;
  return 1;
}

// This is only used for backward deployment hooks, which we currently only support for
// MachO. Add a stub here to make sure it still compiles.
void *swift::lookupSection(const char *segment, const char *section, size_t *outSize) {
  return nullptr;
}

#endif // defined(__ELF__)
