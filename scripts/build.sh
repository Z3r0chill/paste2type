#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
signing_identity="${CODE_SIGN_IDENTITY:--}"
mkdir -p .build/module-cache build/Paste2Type.app/Contents/MacOS
xcrun swiftc -O -target "$(uname -m)-apple-macosx13.0" \
  -module-cache-path "$PWD/.build/module-cache" \
  Sources/TypingPlan.swift Sources/PermissionFlow.swift Sources/main.swift \
  -o build/Paste2Type.app/Contents/MacOS/Paste2Type
cp Resources/Info.plist build/Paste2Type.app/Contents/Info.plist
codesign --force --sign "$signing_identity" build/Paste2Type.app
codesign --verify --strict build/Paste2Type.app
if [ "$signing_identity" = "-" ]; then
  printf '%s\n' 'Ad-hoc build: changed builds may need Accessibility removed and re-added.'
  printf '%s\n' 'Use CODE_SIGN_IDENTITY with the same signing certificate to retain identity across builds.'
fi
printf 'Built %s/build/Paste2Type.app\n' "$PWD"
