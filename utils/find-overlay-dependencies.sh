#!/usr/bin/env zsh
#===--- find-overlay-dependencies.sh - ...by looking at imported headers ---===#
#
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0 with Runtime Library Exception
##
## See http://swift.org/LICENSE.txt for license information
## See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
#
#===------------------------------------------------------------------------===#

# This script uses zsh for its associative array support, because it is only
# intended to be run on macOS and macOS bash is very old.

function usage() {
  echo 'usage:' $0 '<module-name> [update|print]' >&2
  exit 1
}

# `update` edits the cmake file in-place; `print` just prints to console
UPDATE_CMAKE=0
case $# in
1) ;;
2) if [[ $2 == 'update' ]]; then
     UPDATE_CMAKE=1
   elif [[ $2 != 'print' ]]; then
     usage
   fi ;;
*)
  usage ;;
esac

OVERLAYS_PATH=$(dirname "$0")/../stdlib/public/SDK/
CMAKE_PATH=$OVERLAYS_PATH/$1/CMakeLists.txt

# Add both directions to associative array
typeset -A CUSTOM_NAMED_MODULES
CUSTOM_NAMED_MODULES[ObjectiveC]=objc
CUSTOM_NAMED_MODULES[objc]=ObjectiveC
CUSTOM_NAMED_MODULES[Dispatch]=dispatch
CUSTOM_NAMED_MODULES[dispatch]=Dispatch
CUSTOM_NAMED_MODULES[XPC]=xpc
CUSTOM_NAMED_MODULES[xpc]=XPC

# Exclude XCTest/ and CMakeLists.txt
ALL_OVERLAYS=()
for overlay in $(find "$OVERLAYS_PATH" -mindepth 1 -maxdepth 1 -type d ! -name XCTest -exec basename \{\} \;); do
  ALL_OVERLAYS+=${CUSTOM_NAMED_MODULES[$overlay]-$overlay}
done

typeset -A SDKS
SDKS[macosx]="x86_64"
SDKS[iphoneos]="arm64"
SDKS[appletvos]="arm64"
SDKS[watchos]="armv7k"

typeset -A CMAKE_DEPENDS_NAME
CMAKE_DEPENDS_NAME[macosx]="SWIFT_MODULE_DEPENDS_OSX"
CMAKE_DEPENDS_NAME[iphoneos]="SWIFT_MODULE_DEPENDS_IOS"
CMAKE_DEPENDS_NAME[appletvos]="SWIFT_MODULE_DEPENDS_TVOS"
CMAKE_DEPENDS_NAME[watchos]="SWIFT_MODULE_DEPENDS_WATCHOS"

echo $1
for sdk in ${(k)SDKS}; do
  arch=$SDKS[$sdk]
  DEPENDS_ON=()
  printf "%s:\n\t" "$sdk"
  deps=$(echo "@import $1;" | xcrun -sdk $sdk clang -arch $arch -x objective-c - -M -fmodules 2>/dev/null)
  for overlay in $ALL_OVERLAYS; do
    (echo "$deps" |
        egrep -v 'module.(module)?map' |
        egrep -v "\b${CUSTOM_NAMED_MODULES[$1]-$1}\b" |
        egrep -q "\b$overlay\b") &&
        DEPENDS_ON+=${CUSTOM_NAMED_MODULES[$overlay]-$overlay}
  done
  echo " $DEPENDS_ON"
  if [[ $UPDATE_CMAKE == 1 ]]; then
    perl -pi -e "s/^  $CMAKE_DEPENDS_NAME[$sdk].*$/  $CMAKE_DEPENDS_NAME[$sdk] $DEPENDS_ON/" $CMAKE_PATH
  fi
done
echo # newline
