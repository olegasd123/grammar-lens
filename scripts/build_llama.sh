#!/bin/bash
# Build llama.cpp for the current platform
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LLAMA_DIR="$ROOT_DIR/vendor/llama.cpp"
BUILD_DIR="$ROOT_DIR/build/llama"

echo "=== Building llama.cpp ==="
echo "Source: $LLAMA_DIR"
echo "Build: $BUILD_DIR"

mkdir -p "$BUILD_DIR"

# Detect platform
OS="$(uname -s)"
ARCH="$(uname -m)"

CMAKE_ARGS=(
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_SHARED_LIBS=ON
    -DLLAMA_BUILD_TESTS=OFF
    -DLLAMA_BUILD_EXAMPLES=OFF
    -DLLAMA_BUILD_SERVER=OFF
)

case "$OS" in
    Darwin)
        echo "Platform: macOS ($ARCH)"
        CMAKE_ARGS+=(
            -DGGML_METAL=ON
            -DGGML_METAL_EMBED_LIBRARY=ON
        )
        ;;
    Linux)
        echo "Platform: Linux ($ARCH)"
        # Check for Vulkan SDK
        if [ -d "/usr/include/vulkan" ] || [ -d "$VULKAN_SDK" 2>/dev/null ]; then
            echo "Vulkan SDK found"
            CMAKE_ARGS+=(-DGGML_VULKAN=ON)
        fi
        # Check for CUDA
        if command -v nvcc &> /dev/null; then
            echo "CUDA found"
            CMAKE_ARGS+=(-DGGML_CUDA=ON)
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        echo "Platform: Windows ($ARCH)"
        CMAKE_ARGS+=(-DGGML_VULKAN=ON)
        ;;
    *)
        echo "Unknown platform: $OS"
        exit 1
        ;;
esac

echo ""
echo "CMake args: ${CMAKE_ARGS[*]}"
echo ""

cd "$BUILD_DIR"
cmake "$LLAMA_DIR" "${CMAKE_ARGS[@]}"
cmake --build . --config Release -j "$(nproc 2>/dev/null || sysctl -n hw.ncpu)"

echo ""
echo "=== Build complete ==="
echo "Libraries: $BUILD_DIR"
ls -la "$BUILD_DIR"/libllama.* 2>/dev/null || ls -la "$BUILD_DIR"/llama.* 2>/dev/null || echo "(check build output for library location)"
