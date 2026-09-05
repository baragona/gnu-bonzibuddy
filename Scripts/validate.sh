#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build.sh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --check-mesh
Build/BonziBuddy.app/Contents/MacOS/BonziBuddy --validate
swift -module-cache-path .build/clang-cache Scripts/compare.swift

swift -module-cache-path .build/clang-cache Scripts/contact-sheet.swift
