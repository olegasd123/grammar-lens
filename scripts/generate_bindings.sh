#!/bin/bash
# Keep this script safe: runtime bindings are hand-crafted for grammarlens_bridge.h.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== FFI Bindings ==="
echo "Skipping generation."
echo ""
echo "The runtime file is hand-crafted and must stay stable:"
echo "  $ROOT_DIR/packages/llama_inference/lib/src/bindings/llama_bindings.dart"
echo ""
echo "Why:"
echo "  The app uses the bridge API (gl_*) with a compatibility wrapper."
echo "  Running ffigen against llama.h overwrites that file and breaks build."
