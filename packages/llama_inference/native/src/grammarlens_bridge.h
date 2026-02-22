// GrammarLens Bridge - Simplified C API over llama.cpp for Dart FFI
//
// This bridge provides a minimal, FFI-friendly interface to llama.cpp.
// It hides complex struct layouts and manages sampler chains internally.

#ifndef GRAMMARLENS_BRIDGE_H
#define GRAMMARLENS_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef _WIN32
  #define GL_API __declspec(dllexport)
#else
  #define GL_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// ── Lifecycle ────────────────────────────────────────────────────────────────

GL_API void gl_backend_init(void);
GL_API void gl_backend_free(void);

// ── Model ────────────────────────────────────────────────────────────────────

// Opaque handles passed as void* for FFI simplicity.
typedef void* gl_model_t;

GL_API gl_model_t gl_model_load(
    const char* path,
    int32_t     n_gpu_layers,
    bool        use_mmap,
    bool        use_mlock
);
GL_API void     gl_model_free(gl_model_t model);
GL_API int32_t  gl_model_n_ctx_train(gl_model_t model);
GL_API int32_t  gl_model_n_layer(gl_model_t model);
GL_API uint64_t gl_model_size(gl_model_t model);
GL_API int32_t  gl_model_desc(gl_model_t model, char* buf, int32_t buf_size);

// ── Context ──────────────────────────────────────────────────────────────────

typedef void* gl_context_t;

GL_API gl_context_t gl_context_create(
    gl_model_t model,
    int32_t    n_ctx,
    int32_t    n_threads,
    int32_t    n_batch
);
GL_API void gl_context_free(gl_context_t ctx);
GL_API void gl_context_kv_cache_clear(gl_context_t ctx);

// ── Tokenization ─────────────────────────────────────────────────────────────

/// Tokenize text. Returns number of tokens, or negative on error.
/// If tokens is NULL, returns the required buffer size.
GL_API int32_t gl_tokenize(
    gl_model_t model,
    const char* text,
    int32_t     text_len,
    int32_t*    tokens,
    int32_t     n_max_tokens,
    bool        add_special
);

/// Convert a single token to text. Returns bytes written.
GL_API int32_t gl_token_to_piece(
    gl_model_t model,
    int32_t    token,
    char*      buf,
    int32_t    buf_size
);

/// Check if token is end-of-generation.
GL_API bool gl_token_is_eog(gl_model_t model, int32_t token);

/// Get the BOS token id.
GL_API int32_t gl_token_bos(gl_model_t model);

/// Get the EOS token id.
GL_API int32_t gl_token_eos(gl_model_t model);

// ── Decoding ─────────────────────────────────────────────────────────────────

/// Decode a batch of tokens. Returns 0 on success.
GL_API int32_t gl_decode_batch(
    gl_context_t ctx,
    const int32_t* tokens,
    int32_t        n_tokens,
    int32_t        pos_start
);

/// Decode a single token. Returns 0 on success.
GL_API int32_t gl_decode_single(
    gl_context_t ctx,
    int32_t      token,
    int32_t      pos
);

// ── Sampling ─────────────────────────────────────────────────────────────────

typedef void* gl_sampler_t;

/// Create a sampler chain with the given parameters.
/// grammar_gbnf can be NULL for unconstrained generation.
GL_API gl_sampler_t gl_sampler_create(
    gl_model_t  model,
    float       temp,
    float       top_p,
    int32_t     top_k,
    float       repeat_penalty,
    int32_t     penalty_last_n,
    uint32_t    seed,
    const char* grammar_gbnf
);

/// Sample the next token from logits at position idx.
GL_API int32_t gl_sampler_sample(
    gl_sampler_t sampler,
    gl_context_t ctx,
    int32_t      idx
);

/// Accept a token (updates sampler state for repetition penalty, grammar).
GL_API void gl_sampler_accept(gl_sampler_t sampler, int32_t token);

/// Reset sampler state.
GL_API void gl_sampler_reset(gl_sampler_t sampler);

/// Free the sampler chain.
GL_API void gl_sampler_free(gl_sampler_t sampler);

// ── Performance ──────────────────────────────────────────────────────────────

typedef struct {
    double  prompt_eval_time_ms;
    double  eval_time_ms;
    int32_t n_prompt_tokens;
    int32_t n_eval_tokens;
} gl_perf_data;

GL_API gl_perf_data gl_context_perf(gl_context_t ctx);
GL_API void         gl_context_perf_reset(gl_context_t ctx);

// ── GPU Detection ───────────────────────────────────────────────────────────

/// Reports which GPU backends were compiled into the native library
/// and the total system memory available on the device.
typedef struct {
    bool    has_metal;           // Metal backend compiled in
    bool    has_vulkan;          // Vulkan backend compiled in
    bool    has_cuda;            // CUDA backend compiled in
    int64_t system_memory_bytes; // Total physical RAM (0 if unknown)
} gl_gpu_info;

GL_API gl_gpu_info gl_detect_gpu(void);

// ── System Info ──────────────────────────────────────────────────────────────

GL_API const char* gl_system_info(void);

#ifdef __cplusplus
}
#endif

#endif // GRAMMARLENS_BRIDGE_H
