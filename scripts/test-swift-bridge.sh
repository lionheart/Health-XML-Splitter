#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-go-library.sh
swiftc -swift-version 5 \
  -module-cache-path "${TMPDIR:-/tmp}/health-splitter-swift-cache" \
  -F build/HealthSplitter/HealthSplitter.xcframework/macos-arm64_x86_64 \
  "XML Splitter/Parser.swift" tests/BridgeSmoke.swift \
  -framework HealthSplitter -Xlinker -ObjC -lresolv \
  -o build/bridge-smoke
build/bridge-smoke
