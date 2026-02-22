#!/bin/bash
# GrammarLens Developer Environment Setup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PUB_CACHE_BIN="${PUB_CACHE:-$HOME/.pub-cache}/bin"

run_melos() {
    if command -v melos &> /dev/null; then
        melos "$@"
    else
        dart pub global run melos "$@"
    fi
}

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
    if [ -d "$PUB_CACHE_BIN" ]; then
        export PATH="$PATH:$PUB_CACHE_BIN"
    fi
fi
if ! command -v melos &> /dev/null; then
    echo "WARNING: melos is not in PATH. Using 'dart pub global run melos'."
    echo "TIP: add this to shell profile: export PATH=\"\$PATH:$PUB_CACHE_BIN\""
fi
MELOS_VERSION="$(run_melos --version 2>&1 | head -1)"
echo "Melos: $MELOS_VERSION"
if [[ "$MELOS_VERSION" == 7.* ]] && [ -f "$ROOT_DIR/melos.yaml" ]; then
    echo "NOTE: Melos 7 may not support this repo's melos.yaml format."
fi

# Initialize git submodules (llama.cpp)
echo ""
echo "=== Initializing git submodules ==="
git -C "$ROOT_DIR" submodule update --init --recursive

# Bootstrap the monorepo
echo ""
echo "=== Bootstrapping monorepo ==="
if (
    cd "$ROOT_DIR"
    run_melos bootstrap
); then
    echo "Bootstrap done with Melos."
else
    echo "WARNING: Melos bootstrap failed."
    echo "Falling back to Dart workspace bootstrap (dart pub get)."
    (
        cd "$ROOT_DIR"
        dart pub get
    )
fi

# Generate FFI bindings (if ffigen is available)
echo ""
echo "=== Generating FFI bindings ==="
(
    cd "$ROOT_DIR/packages/llama_inference"
    if dart pub deps 2>/dev/null | grep -q ffigen; then
        dart run ffigen --config ffigen.yaml || echo "WARNING: FFI generation failed (expected if llama.cpp headers not found)"
    fi
)

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Run 'dart analyze' to check for issues"
echo "  2. Run package tests (for example: flutter test apps/grammarlens)"
echo "  3. Open apps/grammarlens in your IDE"
echo "  4. Download a GGUF model from the app's Model Manager"
