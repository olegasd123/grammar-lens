#!/bin/bash
# Regenerate Dart FFI bindings from llama.cpp headers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Generating FFI Bindings ==="

cd "$ROOT_DIR/packages/llama_inference"

# Ensure dependencies are available
dart pub get

# Run ffigen
dart run ffigen --config ffigen.yaml

echo ""
echo "=== Bindings generated ==="
echo "Output: lib/src/bindings/llama_bindings.dart"
