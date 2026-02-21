cmake_minimum_required(VERSION 3.18)
project(llama_inference_native C CXX)

# C++ standard for llama.cpp
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Path to llama.cpp source (relative to this file)
set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../vendor/llama.cpp")

# Build llama.cpp as a shared library
set(BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries" FORCE)

# GPU backend options (configurable per platform)
option(GGML_METAL  "Enable Metal GPU backend (macOS/iOS)" OFF)
option(GGML_VULKAN "Enable Vulkan GPU backend" OFF)
option(GGML_CUDA   "Enable CUDA GPU backend" OFF)

# Platform-specific GPU defaults
if(APPLE)
  set(GGML_METAL ON CACHE BOOL "" FORCE)
  set(GGML_METAL_EMBED_LIBRARY ON CACHE BOOL "" FORCE)
elseif(ANDROID)
  set(GGML_VULKAN ON CACHE BOOL "" FORCE)
elseif(WIN32 OR (UNIX AND NOT APPLE))
  # Default to Vulkan on desktop Linux/Windows; CUDA users can override
  set(GGML_VULKAN ON CACHE BOOL "" FORCE)
endif()

# Add llama.cpp as a subdirectory — builds libllama
add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)

# Create our bridge shared library
add_library(llama_inference_native SHARED
  src/grammarlens_bridge.c
)

target_include_directories(llama_inference_native PRIVATE
  src
  ${LLAMA_CPP_DIR}/include
  ${LLAMA_CPP_DIR}/ggml/include
)

target_link_libraries(llama_inference_native PRIVATE llama)

# Ensure symbols are exported
set_target_properties(llama_inference_native PROPERTIES
  C_VISIBILITY_PRESET default
  VISIBILITY_INLINES_HIDDEN OFF
)

# On macOS, set rpath so the dylib can find libllama
if(APPLE)
  set_target_properties(llama_inference_native PROPERTIES
    INSTALL_RPATH "@loader_path"
    BUILD_WITH_INSTALL_RPATH TRUE
    MACOSX_RPATH TRUE
  )
endif()

# Install targets
install(TARGETS llama_inference_native
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
)
