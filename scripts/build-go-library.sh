#!/bin/bash
set -euo pipefail

cd "${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
go_binary="${GO_BINARY:-go}"
# Child commands run by gomobile must use the same resolved Go toolchain.
go_root="$("$go_binary" env GOROOT)"
go_binary="$go_root/bin/go"
export PATH="$go_root/bin:$PATH"
output="${TARGET_TEMP_DIR:-$PWD/build}/HealthSplitter"
mkdir -p "$output/tools"

# gomobile reconstructs the complete module graph for its generated build.
# Resolve it here so download failures are reported before binding generation.
"$go_binary" list -m all > /dev/null

# Build both tools from the versions pinned by the go.mod tool directives.
# gomobile finds gobind on PATH; no global installation or gomobile init is needed.
"$go_binary" build -o "$output/tools/gomobile" golang.org/x/mobile/cmd/gomobile
"$go_binary" build -o "$output/tools/gobind" golang.org/x/mobile/cmd/gobind
export PATH="$output/tools:$PATH"

# A single universal macOS slice works for both Xcode targets and configurations.
gomobile bind -target=macos/arm64,macos/amd64 \
  -macosversion="${MACOSX_DEPLOYMENT_TARGET:-13.0}" -trimpath \
  -o "$output/HealthSplitter.xcframework" ./bindings/healthsplitter
