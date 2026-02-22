/// Flutter FFI bindings for llama.cpp - local LLM inference engine.
///
/// Provides high-level Dart API for loading GGUF models and running
/// inference using llama.cpp, with isolate-based execution to keep
/// the UI thread responsive.
library;

export 'src/android_memory_info.dart';
export 'src/gpu_backend.dart';
export 'src/inference_config.dart';
export 'src/inference_result.dart';
export 'src/isolate_inference.dart';
export 'src/llama_context.dart';
export 'src/llama_model.dart';
export 'src/llama_session.dart';
export 'src/memory_manager.dart';
