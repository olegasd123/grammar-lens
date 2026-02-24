// GrammarLens Bridge - Implementation
//
// Thin C wrapper over llama.cpp that provides a clean FFI interface.

#include "grammarlens_bridge.h"
#include "llama.h"

#include <stdlib.h>
#include <string.h>

// Platform headers for system memory detection
#ifdef __APPLE__
  #include <sys/types.h>
  #include <sys/sysctl.h>
#elif defined(__linux__) || defined(__ANDROID__)
  #include <sys/sysinfo.h>
#elif defined(_WIN32)
  #include <windows.h>
#endif

// ── Lifecycle ────────────────────────────────────────────────────────────────

GL_API void gl_backend_init(void) {
    llama_backend_init();
}

GL_API void gl_backend_free(void) {
    llama_backend_free();
}

// ── Model ────────────────────────────────────────────────────────────────────

GL_API gl_model_t gl_model_load(
    const char* path,
    int32_t     n_gpu_layers,
    bool        use_mmap,
    bool        use_mlock
) {
    struct llama_model_params params = llama_model_default_params();
    params.n_gpu_layers = n_gpu_layers;
    params.use_mmap     = use_mmap;
    params.use_mlock    = use_mlock;

    struct llama_model* model = llama_model_load_from_file(path, params);
    return (gl_model_t)model;
}

GL_API void gl_model_free(gl_model_t model) {
    if (model) {
        llama_model_free((struct llama_model*)model);
    }
}

GL_API int32_t gl_model_n_ctx_train(gl_model_t model) {
    return llama_model_n_ctx_train((const struct llama_model*)model);
}

GL_API int32_t gl_model_n_layer(gl_model_t model) {
    return llama_model_n_layer((const struct llama_model*)model);
}

GL_API uint64_t gl_model_size(gl_model_t model) {
    return llama_model_size((const struct llama_model*)model);
}

GL_API int32_t gl_model_desc(gl_model_t model, char* buf, int32_t buf_size) {
    return llama_model_desc((const struct llama_model*)model, buf, buf_size);
}

// ── Context ──────────────────────────────────────────────────────────────────

GL_API gl_context_t gl_context_create(
    gl_model_t model,
    int32_t    n_ctx,
    int32_t    n_threads,
    int32_t    n_batch
) {
    struct llama_context_params params = llama_context_default_params();
    params.n_ctx   = (uint32_t)n_ctx;
    params.n_batch = (uint32_t)n_batch;

    if (n_threads > 0) {
        params.n_threads       = n_threads;
        params.n_threads_batch = n_threads;
    }

    struct llama_context* ctx = llama_init_from_model(
        (struct llama_model*)model, params
    );
    return (gl_context_t)ctx;
}

GL_API void gl_context_free(gl_context_t ctx) {
    if (ctx) {
        llama_free((struct llama_context*)ctx);
    }
}

GL_API void gl_context_kv_cache_clear(gl_context_t ctx) {
    if (ctx) {
        llama_memory_t mem = llama_get_memory((struct llama_context*)ctx);
        if (mem) {
            llama_memory_clear(mem, true);
        }
    }
}

// ── Tokenization ─────────────────────────────────────────────────────────────

GL_API int32_t gl_tokenize(
    gl_model_t  model,
    const char* text,
    int32_t     text_len,
    int32_t*    tokens,
    int32_t     n_max_tokens,
    bool        add_special
) {
    const struct llama_vocab* vocab = llama_model_get_vocab(
        (const struct llama_model*)model
    );
    return llama_tokenize(vocab, text, text_len, tokens, n_max_tokens,
                          add_special, true);
}

GL_API int32_t gl_token_to_piece(
    gl_model_t model,
    int32_t    token,
    char*      buf,
    int32_t    buf_size
) {
    const struct llama_vocab* vocab = llama_model_get_vocab(
        (const struct llama_model*)model
    );
    return llama_token_to_piece(vocab, token, buf, buf_size, 0, true);
}

GL_API bool gl_token_is_eog(gl_model_t model, int32_t token) {
    const struct llama_vocab* vocab = llama_model_get_vocab(
        (const struct llama_model*)model
    );
    return llama_vocab_is_eog(vocab, token);
}

GL_API int32_t gl_token_bos(gl_model_t model) {
    const struct llama_vocab* vocab = llama_model_get_vocab(
        (const struct llama_model*)model
    );
    return llama_vocab_bos(vocab);
}

GL_API int32_t gl_token_eos(gl_model_t model) {
    const struct llama_vocab* vocab = llama_model_get_vocab(
        (const struct llama_model*)model
    );
    return llama_vocab_eos(vocab);
}

// ── Decoding ─────────────────────────────────────────────────────────────────

GL_API int32_t gl_decode_batch(
    gl_context_t   ctx,
    const int32_t* tokens,
    int32_t        n_tokens,
    int32_t        pos_start
) {
    if (ctx == NULL || tokens == NULL || n_tokens <= 0 || pos_start < 0) {
        return -1;
    }

    struct llama_context* context = (struct llama_context*)ctx;
    const uint32_t n_ctx = llama_n_ctx(context);
    const uint32_t n_batch = llama_n_batch(context);
    if (n_batch == 0) {
        return -1;
    }

    const int64_t end_pos = (int64_t)pos_start + (int64_t)n_tokens;
    if (end_pos > (int64_t)n_ctx) {
        // Requested decode would exceed KV-cache capacity.
        return -2;
    }

    int32_t consumed = 0;
    while (consumed < n_tokens) {
        int32_t chunk = n_tokens - consumed;
        if ((uint32_t)chunk > n_batch) {
            chunk = (int32_t)n_batch;
        }

        struct llama_batch batch = llama_batch_init(chunk, 0, 1);

        for (int32_t i = 0; i < chunk; i++) {
            const int32_t token_index = consumed + i;
            batch.token[i]     = tokens[token_index];
            batch.pos[i]       = pos_start + token_index;
            batch.n_seq_id[i]  = 1;
            batch.seq_id[i][0] = 0;
            // Keep logits only for the last token of the whole prompt.
            batch.logits[i]    = (token_index == n_tokens - 1) ? 1 : 0;
        }
        batch.n_tokens = chunk;

        const int32_t result = llama_decode(context, batch);
        llama_batch_free(batch);
        if (result != 0) {
            return result;
        }

        consumed += chunk;
    }

    return 0;
}

GL_API int32_t gl_decode_single(
    gl_context_t ctx,
    int32_t      token,
    int32_t      pos
) {
    if (ctx == NULL || pos < 0) {
        return -1;
    }

    struct llama_context* context = (struct llama_context*)ctx;
    const uint32_t n_ctx = llama_n_ctx(context);
    if ((uint32_t)pos >= n_ctx) {
        // Token position would exceed KV-cache capacity.
        return -2;
    }

    struct llama_batch batch = llama_batch_init(1, 0, 1);

    batch.token[0]     = token;
    batch.pos[0]       = pos;
    batch.n_seq_id[0]  = 1;
    batch.seq_id[0][0] = 0;
    batch.logits[0]    = 1;
    batch.n_tokens     = 1;

    int32_t result = llama_decode(context, batch);
    llama_batch_free(batch);
    return result;
}

// ── Sampling ─────────────────────────────────────────────────────────────────

GL_API gl_sampler_t gl_sampler_create(
    gl_model_t  model,
    float       temp,
    float       top_p,
    int32_t     top_k,
    float       repeat_penalty,
    int32_t     penalty_last_n,
    uint32_t    seed,
    const char* grammar_gbnf
) {
    struct llama_sampler_chain_params chain_params = llama_sampler_chain_default_params();
    chain_params.no_perf = false;

    struct llama_sampler* chain = llama_sampler_chain_init(chain_params);

    // Repetition penalty
    if (repeat_penalty != 1.0f && penalty_last_n > 0) {
        llama_sampler_chain_add(chain,
            llama_sampler_init_penalties(penalty_last_n, repeat_penalty, 0.0f, 0.0f));
    }

    // Top-K
    if (top_k > 0) {
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(top_k));
    }

    // Top-P
    if (top_p < 1.0f) {
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(top_p, 1));
    }

    // Temperature
    if (temp > 0.0f) {
        llama_sampler_chain_add(chain, llama_sampler_init_temp(temp));
        llama_sampler_chain_add(chain, llama_sampler_init_dist(seed));
    } else {
        llama_sampler_chain_add(chain, llama_sampler_init_greedy());
    }

    // Grammar constraint
    if (grammar_gbnf != NULL && grammar_gbnf[0] != '\0') {
        const struct llama_vocab* vocab = llama_model_get_vocab(
            (const struct llama_model*)model
        );
        llama_sampler_chain_add(chain,
            llama_sampler_init_grammar(vocab, grammar_gbnf, "root"));
    }

    return (gl_sampler_t)chain;
}

GL_API int32_t gl_sampler_sample(
    gl_sampler_t sampler,
    gl_context_t ctx,
    int32_t      idx
) {
    return llama_sampler_sample(
        (struct llama_sampler*)sampler,
        (struct llama_context*)ctx,
        idx
    );
}

GL_API void gl_sampler_accept(gl_sampler_t sampler, int32_t token) {
    llama_sampler_accept((struct llama_sampler*)sampler, token);
}

GL_API void gl_sampler_reset(gl_sampler_t sampler) {
    llama_sampler_reset((struct llama_sampler*)sampler);
}

GL_API void gl_sampler_free(gl_sampler_t sampler) {
    if (sampler) {
        llama_sampler_free((struct llama_sampler*)sampler);
    }
}

// ── Performance ──────────────────────────────────────────────────────────────

GL_API gl_perf_data gl_context_perf(gl_context_t ctx) {
    struct llama_perf_context_data perf = llama_perf_context(
        (const struct llama_context*)ctx
    );
    gl_perf_data result;
    result.prompt_eval_time_ms = perf.t_p_eval_ms;
    result.eval_time_ms        = perf.t_eval_ms;
    result.n_prompt_tokens     = perf.n_p_eval;
    result.n_eval_tokens       = perf.n_eval;
    return result;
}

GL_API void gl_context_perf_reset(gl_context_t ctx) {
    llama_perf_context_reset((struct llama_context*)ctx);
}

// ── GPU Detection ───────────────────────────────────────────────────────────

static int64_t _gl_get_system_memory(void) {
#ifdef __APPLE__
    int64_t mem = 0;
    size_t  len = sizeof(mem);
    if (sysctlbyname("hw.memsize", &mem, &len, NULL, 0) == 0) {
        return mem;
    }
    return 0;
#elif defined(__linux__) || defined(__ANDROID__)
    struct sysinfo si;
    if (sysinfo(&si) == 0) {
        return (int64_t)si.totalram * (int64_t)si.mem_unit;
    }
    return 0;
#elif defined(_WIN32)
    MEMORYSTATUSEX status;
    status.dwLength = sizeof(status);
    if (GlobalMemoryStatusEx(&status)) {
        return (int64_t)status.ullTotalPhys;
    }
    return 0;
#else
    return 0;
#endif
}

GL_API gl_gpu_info gl_detect_gpu(void) {
    gl_gpu_info info;
    memset(&info, 0, sizeof(info));

#ifdef GGML_USE_METAL
    info.has_metal = true;
#endif

#ifdef GGML_USE_VULKAN
    info.has_vulkan = true;
#endif

#ifdef GGML_USE_CUDA
    info.has_cuda = true;
#endif

    info.system_memory_bytes = _gl_get_system_memory();

    return info;
}

// ── System Info ──────────────────────────────────────────────────────────────

GL_API const char* gl_system_info(void) {
    return llama_print_system_info();
}
