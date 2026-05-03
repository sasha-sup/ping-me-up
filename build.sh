#!/usr/bin/env bash
# Build pingmeup release binary.
#
# Default: glibc target (works on any Linux with glibc).
# To build a fully static musl binary, pass --musl (requires `musl-tools`):
#   sudo apt-get install musl-tools
#   ./build.sh --musl

set -Eeuo pipefail

cd "$(dirname "$0")"

TARGET=""
if [[ "${1:-}" == "--musl" ]]; then
    TARGET="x86_64-unknown-linux-musl"
fi

if [[ -n "$TARGET" ]]; then
    cargo build --release --target "$TARGET"
    BIN_PATH="target/${TARGET}/release/pingmeup"
else
    cargo build --release
    BIN_PATH="target/release/pingmeup"
fi

if command -v strip >/dev/null 2>&1; then
    strip "$BIN_PATH" || true
fi

ls -lh "$BIN_PATH"
file "$BIN_PATH" 2>/dev/null || true
echo
echo "Built: $BIN_PATH"
