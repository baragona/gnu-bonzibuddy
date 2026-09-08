#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
for asset in FanRigged.mesh FanRig.json FanMorphs.bin FanMorphs.json FanTeeth.mesh ATTRIBUTION.txt; do
    if [[ ! -s "Resources/FanModel/$asset" ]]; then
        echo "Missing required bundled fan asset: $asset" >&2
        exit 1
    fi
done
if [[ ! -s Resources/Props/globe-land.png || ! -s Resources/Props/FanSunglasses.mesh ]]; then
    echo "Missing required prop asset: globe-land.png or FanSunglasses.mesh" >&2
    exit 1
fi
mkdir -p .build Validation Resources
xcrun swiftc -O -swift-version 5 -module-cache-path .build/clang-cache Sources/BonziBuddy/*.swift -o .build/BonziBuddy
if [[ ! -f Resources/Bonzi.mesh || Sources/BonziBuddy/Character.swift -nt Resources/Bonzi.mesh || Sources/BonziBuddy/Mesh.swift -nt Resources/Bonzi.mesh || Sources/BonziBuddy/Animation.swift -nt Resources/Bonzi.mesh ]]; then
    .build/BonziBuddy --bake-mesh
fi
APP="$PWD/Build/BonziBuddy.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/BonziBuddy "$APP/Contents/MacOS/BonziBuddy"
cp Sources/BonziBuddy/Shaders.metal Resources/Bonzi.mesh LICENSE NOTICE.md "$APP/Contents/Resources/"
mkdir -p "$APP/Contents/Resources/Props"
cp Resources/Props/* "$APP/Contents/Resources/Props/"
mkdir -p "$APP/Contents/Resources/FanModel"
cp Resources/FanModel/FanRigged.mesh Resources/FanModel/FanRig.json Resources/FanModel/FanMorphs.bin Resources/FanModel/FanMorphs.json Resources/FanModel/FanTeeth.mesh Resources/FanModel/ATTRIBUTION.txt "$APP/Contents/Resources/FanModel/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>BonziBuddy</string>
<key>CFBundleIdentifier</key><string>local.bonzibuddy.mac</string>
<key>CFBundleName</key><string>GNU BonziBuddy</string>
<key>CFBundleDisplayName</key><string>GNU BonziBuddy</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
