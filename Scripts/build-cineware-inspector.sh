#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SDK_DIR="${1:-/tmp/bonzi-cineware-sdk}"
OUTPUT="${2:-/tmp/bonzi-cineware-inspect}"
xcrun clang++ -arch x86_64 -std=c++11 -fno-rtti \
  -D__MAC -D__64BIT -DMAXON_TARGET_RELEASE -DMAXON_TARGET_OSX -DMAXON_TARGET_64BIT \
  -I"$SDK_DIR/includes" Scripts/cineware-inspect.cpp \
  -L"$SDK_DIR/libraries/osx/release" -lcinewarelib -ljpeglib \
  -framework AppKit -framework CoreFoundation -framework CoreAudio -framework Carbon -framework IOKit \
  -o "$OUTPUT"
