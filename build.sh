#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd -P)"
APP="$PWD/build/视频下载助手.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/runtime" "$ROOT/.build/app-module-cache"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/download.py Resources/AppIcon.icns "$APP/Contents/Resources/"
if [ -n "${RUNTIME_SOURCE:-}" ]; then
  ditto "$RUNTIME_SOURCE" "$APP/Contents/Resources/runtime"
else
  /opt/homebrew/bin/python3 -m pip install --pre --upgrade --target "$APP/Contents/Resources/runtime" -r requirements.txt
fi
swiftc -O -target arm64-apple-macos13.0 -module-cache-path "$ROOT/.build/app-module-cache" Source/Queue.swift Source/LinkEditor.swift Source/main.swift -o "$APP/Contents/MacOS/VideoDownloader" -framework Cocoa
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
