cmake_minimum_required(VERSION 3.18)
project(llama_inference_native)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Path to llama.cpp source (relative to this file)
set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../vendor/llama.cpp")

# GPU backend options (configurable per platform)
option(GGML_METAL "Enable Metal GPU backend (macOS/iOS)" OFF)
option(GGML_VULKAN "Enable Vulkan GPU backend (Windows/Linux/Android)" OFF)
option(GGML_CUDA "Enable CUDA GPU backend (Windows/Linux)" OFF)

# Platform-specific GPU defaults
if(APPLE)
  set(GGML_METAL ON)
  set(GGML_METAL_EMBED_LIBRARY ON)
elseif(ANDROID)
  set(GGML_VULKAN ON)
elseif(WIN32 OR UNIX)
  set(GGML_VULKAN ON)
endif()

# Add llama.cpp as a subdirectory
add_subdirectory(${LLAMA_CPP_DIR} llama.cpp)

# Create the shared library that Flutter will load via FFI
add_library(llama_inference_native SHARED
  ${LLAMA_CPP_DIR}/include/llama.h
)

target_link_libraries(llama_inference_native PRIVATE llama)

target_include_directories(llama_inference_native PUBLIC
  ${LLAMA_CPP_DIR}/include
  ${LLAMA_CPP_DIR}/ggml/include
)

# Install targets
install(TARGETS llama_inference_native
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
)
