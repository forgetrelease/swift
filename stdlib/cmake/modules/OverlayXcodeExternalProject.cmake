#===--- OverlayXcodeExternalProject.cmake - build overlays with Xcode   --===#
#
# This source file is part of the Swift.org open source project
#
# Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
#
#===----------------------------------------------------------------------===#
include(ExternalProject)

# Build an overlay project from Xcode sources
# for given SDKs. For now tailored for
# Foundation and CoreFoundation
function(add_overlay_xcode_project overlay)
  set(options)
  set(oneValueArgs "SOURCE_DIR" "BUILD_TARGET")
  set(multiValueArgs "DEPENDS" "TARGET_SDKS" "ADDITIONAL_XCODEBUILD_ARGUMENTS")

  cmake_parse_arguments(AOXP "${options}" "${oneValueArgs}"
                                "${multiValueArgs}" ${ARGN} )

  foreach(sdk ${AOXP_TARGET_SDKS})
    add_overlay_xcode_project_single(
      ${overlay}
      SOURCE_DIR ${AOXP_SOURCE_DIR}
      BUILD_TARGET ${AOXP_BUILD_TARGET}
      DEPENDS ${AOXP_DEPENDS}
      ADDITIONAL_XCODEBUILD_ARGUMENTS ${AOXP_ADDITIONAL_XCODEBUILD_ARGUMENTS}
      TARGET_SDK ${sdk})
  endforeach()
endfunction()

function(add_overlay_xcode_project_single overlay)
  set(options)
  set(oneValueArgs "SOURCE_DIR" "BUILD_TARGET" "TARGET_SDK")
  set(multiValueArgs "DEPENDS" "ADDITIONAL_XCODEBUILD_ARGUMENTS")

  cmake_parse_arguments(AOXP "${options}" "${oneValueArgs}"
                                "${multiValueArgs}" ${ARGN} )

  set(sdk ${AOXP_TARGET_SDK})
  set(sdk_name ${SWIFT_SDK_${sdk}_LIB_SUBDIR})
  set(sdk_path ${SWIFT_SDK_${sdk}_PATH})
  string(JOIN " " joined_sdk_archs ${SWIFT_SDK_${sdk}_ARCHITECTURES})
  set(temp_install_subpath "usr/lib/swift")

  set(dependencies swiftCore ${AOXP_DEPENDS})
  list(TRANSFORM dependencies APPEND "-${sdk_name}")

  ExternalProject_Add(${overlay}Overlay-${sdk_name}
    SOURCE_DIR ${AOXP_SOURCE_DIR}
    INSTALL_DIR  ${SWIFTLIB_DIR}/${sdk_name}
    CONFIGURE_COMMAND ""
    # let update-checkout and xcodebuild
    # figure out if we have to rebuild
    BUILD_ALWAYS 1
    BUILD_IN_SOURCE TRUE
    BUILD_COMMAND xcodebuild install
    -target ${AOXP_BUILD_TARGET}
    -sdk ${sdk_path}
    SYMROOT=<TMP_DIR>
    OBJROOT=<TMP_DIR>
    DSTROOT=<TMP_DIR>
    SWIFT_EXEC=${SWIFT_NATIVE_SWIFT_TOOLS_PATH}/swiftc
    MACOSX_DEPLOYMENT_TARGET=${SWIFT_DARWIN_DEPLOYMENT_VERSION_OSX}
    IPHONEOS_DEPLOYMENT_TARGET=${SWIFT_DARWIN_DEPLOYMENT_VERSION_IOS}
    ARCHS=${joined_sdk_archs}
    ${AOXP_ADDITIONAL_XCODEBUILD_ARGUMENTS}
    # This should have been the install command,
    # but need to fold into the build one
    # to be sure the dependencies are considered correctly
    COMMAND ditto <TMP_DIR>/${temp_install_subpath} <INSTALL_DIR>
    INSTALL_COMMAND ""
    BUILD_BYPRODUCTS <INSTALL_DIR>/${overlay}.swiftmodule
    <INSTALL_DIR>/libswift${overlay}.dylib
    EXCLUDE_FROM_ALL TRUE
    DEPENDS ${dependencies})
endfunction()

# Setup CMake targets and dependencies
# for overlays built with add_overlay_xcode_project
# that existing code expects,
# so to minimize disruption during migration to
# building with Xcode and allow to switch
# between implementations
function(add_overlay_targets overlay)
  set(options)
  set(oneValueArgs)
  set(multiValueArgs "TARGET_SDKS")

  cmake_parse_arguments(AOT "${options}" "${oneValueArgs}"
                                "${multiValueArgs}" ${ARGN} )

  foreach(sdk ${AOT_TARGET_SDKS})
    add_overlay_targets_single(
      ${overlay}
      TARGET_SDK ${sdk})
  endforeach()
endfunction()

function(add_overlay_targets_single overlay)
  set(options)
  set(oneValueArgs "TARGET_SDK")
  set(multiValueArgs)

  cmake_parse_arguments(AOT "${options}" "${oneValueArgs}"
                                "${multiValueArgs}" ${ARGN} )

  set(sdk ${AOT_TARGET_SDK})
  set(sdk_name ${SWIFT_SDK_${sdk}_LIB_SUBDIR})
  set(sdk_supported_archs
    ${SWIFT_SDK_${sdk}_ARCHITECTURES}
    ${SWIFT_SDK_${sdk}_MODULE_ARCHITECTURES})
  list(REMOVE_DUPLICATES sdk_supported_archs)
  set(xcode_overlay_target_name ${overlay}Overlay-${sdk_name})

  foreach(arch ${sdk_supported_archs})
    set(variant_suffix "${sdk_name}-${arch}")

    set(overlay_dylib_target swift${overlay}-${variant_suffix})
    add_library(${overlay_dylib_target} SHARED IMPORTED GLOBAL)
    set_property(TARGET ${overlay_dylib_target}
      PROPERTY IMPORTED_LOCATION ${SWIFTLIB_DIR}/${sdk_name}/libswift${overlay}.dylib)
    add_dependencies(${overlay_dylib_target} ${xcode_overlay_target_name})

    set(overlay_swiftmodule_target swift${overlay}-swiftmodule-${variant_suffix})
    add_custom_target(${overlay_swiftmodule_target})
    add_dependencies(${overlay_swiftmodule_target} ${xcode_overlay_target_name})
    if(SWIFT_ENABLE_MACCATALYST AND sdk STREQUAL "OSX")
      set(overlay_maccatalyst_swiftmodule_target swift${overlay}-swiftmodule-maccatalyst-${arch})
      add_custom_target(${overlay_maccatalyst_swiftmodule_target})
      add_dependencies(${overlay_maccatalyst_swiftmodule_target} ${xcode_overlay_target_name})
    endif()

    add_dependencies(swift-stdlib-${variant_suffix} ${xcode_overlay_target_name})
  endforeach()

  add_dependencies(sdk-overlay ${xcode_overlay_target_name})
endfunction()
