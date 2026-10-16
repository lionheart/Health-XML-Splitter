#!/bin/bash
set -euo pipefail

cd "${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
go_binary="${GO_BINARY:-go}"
output="${TARGET_TEMP_DIR:-$PWD/build}/HealthSplitter"
mkdir -p "$output"

archives=()
for architecture in ${ARCHS:-$(uname -m)}; do
  case "$architecture" in
    arm64) go_arch=arm64 ;;
    x86_64) go_arch=amd64 ;;
    *) echo "Unsupported macOS architecture: $architecture" >&2; exit 1 ;;
  esac
  archive="$output/$architecture/libHealthSplitter.a"
  mkdir -p "$(dirname "$archive")"
  GOOS=darwin GOARCH="$go_arch" CGO_ENABLED=1 \
    CGO_CFLAGS="-arch $architecture -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET:-13.0}" \
    CGO_LDFLAGS="-arch $architecture -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET:-13.0}" \
    "$go_binary" build -trimpath -buildmode=c-archive -o "$archive" ./cmd/splitter-library
  archives+=("$archive")
done
xcrun lipo -create "${archives[@]}" -output "$output/libHealthSplitter.a"
