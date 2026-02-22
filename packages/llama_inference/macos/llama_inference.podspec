Pod::Spec.new do |s|
  s.name             = 'llama_inference'
  s.version          = '0.1.0'
  s.summary          = 'FFI bindings for local llama.cpp inference.'
  s.description      = <<-DESC
Provides Flutter macOS integration metadata for the llama_inference package.
Native inference is loaded through Dart FFI.
                       DESC
  s.homepage         = 'https://grammarlens.app'
  s.license          = { :type => 'MIT' }
  s.author           = { 'GrammarLens' => 'dev@grammarlens.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.script_phase = {
    :name => 'Build llama_inference native dylibs',
    :execution_position => :before_compile,
    :script => <<-SCRIPT
set -euo pipefail

if [ "${PLATFORM_NAME:-}" != "macosx" ]; then
  exit 0
fi

PKG_DIR="$(cd "${PODS_TARGET_SRCROOT}/.." && pwd -P)"
NATIVE_SRC="${PKG_DIR}/native"
BUILD_DIR="${PKG_DIR}/build/native_macos_pod"

cmake -S "${NATIVE_SRC}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release
cmake --build "${BUILD_DIR}" --config Release -j 8

DEST_DIR="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}/Versions/A/Frameworks"
mkdir -p "${DEST_DIR}"

cp -f "${BUILD_DIR}/libllama_inference_native.dylib" "${DEST_DIR}/"
for dylib in "${BUILD_DIR}"/bin/libllama*.dylib "${BUILD_DIR}"/bin/libggml*.dylib; do
  if [ -f "${dylib}" ]; then
    cp -f "${dylib}" "${DEST_DIR}/"
  fi
done
SCRIPT
  }
end
