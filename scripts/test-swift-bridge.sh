#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-go-library.sh
swiftc -swift-version 5 \
  -module-cache-path "${TMPDIR:-/tmp}/health-splitter-swift-cache" \
  -import-objc-header "XML Splitter/GoSplitter-Bridging-Header.h" \
  "XML Splitter/Parser.swift" tests/BridgeSmoke.swift \
  -L build/HealthSplitter -lHealthSplitter -lresolv \
  -o build/bridge-smoke
build/bridge-smoke
