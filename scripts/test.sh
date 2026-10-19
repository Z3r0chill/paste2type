#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache
xcrun swiftc -module-cache-path "$PWD/.build/module-cache" \
  Sources/TypingPlan.swift Sources/PermissionFlow.swift tests/main.swift -o .build/typing-tests
.build/typing-tests
