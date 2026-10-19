#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
APP="$PROJECT_ROOT/dist/流光桌面.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PROJECT_ROOT/build/module-cache"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/build/module-cache"
swiftc -swift-version 5 -parse-as-library -O -target "$(uname -m)-apple-macos13.0" \
    -module-cache-path "$PROJECT_ROOT/build/module-cache" \
    Sources/*.swift -o "$APP/Contents/MacOS/LumaDesktop" \
    -framework AppKit -framework SwiftUI -framework AVFoundation -framework QuartzCore -framework ServiceManagement -framework IOKit
cp Resources/Info.plist "$APP/Contents/Info.plist"
for localization in Resources/*.lproj; do
    cp -R "$localization" "$APP/Contents/Resources/"
done
swift scripts/make-icon.swift "$PROJECT_ROOT/build/AppIcon.iconset"
python3 scripts/package-icon.py "$PROJECT_ROOT/build/AppIcon.iconset" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf '已构建：%s\n' "$APP"
