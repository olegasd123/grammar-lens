#!/bin/bash
# GrammarLens Developer Environment Setup
set -euo pipefail

echo "=== GrammarLens Dev Setup ==="
echo ""

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "ERROR: Flutter SDK not found. Install from https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "Flutter: $(flutter --version | head -1)"

# Check Dart
echo "Dart: $(dart --version 2>&1)"

# Check Melos
if ! command -v melos &> /dev/null; then
    echo "Installing Melos..."
    dart pub global activate melos
fi
echo "Melos: $(melos --version 2>&1)"

# Initialize git submodules (llama.cpp)
echo ""
echo "=== Initializing git submodules ==="
git submodule update --init --recursive

# Bootstrap the monorepo
echo ""
echo "=== Bootstrapping monorepo ==="
melos bootstrap

# Generate FFI bindings (if ffigen is available)
echo ""
echo "=== Generating FFI bindings ==="
cd packages/llama_inference
if dart pub deps 2>/dev/null | grep -q ffigen; then
    dart run ffigen --config ffigen.yaml || echo "WARNING: FFI generation failed (expected if llama.cpp headers not found)"
fi
cd ../..

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Run 'melos analyze' to check for issues"
echo "  2. Run 'melos test' to run all tests"
echo "  3. Open apps/grammarlens in your IDE"
echo "  4. Download a GGUF model from the app's Model Manager"
