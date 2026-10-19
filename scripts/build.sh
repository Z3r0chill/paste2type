#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache build/Paste2Type.app/Contents/MacOS
xcrun swiftc -O -target "$(uname -m)-apple-macosx13.0" \
  -module-cache-path "$PWD/.build/module-cache" \
  Sources/TypingPlan.swift Sources/main.swift \
  -o build/Paste2Type.app/Contents/MacOS/Paste2Type
cp Resources/Info.plist build/Paste2Type.app/Contents/Info.plist
codesign --force --sign - build/Paste2Type.app
printf 'Built %s/build/Paste2Type.app\n' "$PWD"
