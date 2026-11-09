#include <cstring>
#include <cstdlib>
#include <string>
#include <vector>
#include "llama.h"

static llama_model* g_model = nullptr;
static std::string g_loaded_path = "";
static std::string g_last_output = "";

extern "C" {

__attribute__((visibility("default"))) __attribute__((used))
int mediq_llama_load_model(const char* model_path) {
    if (!model_path) return 0;
    if (g_model != nullptr && g_loaded_path == model_path) {
        return 1;
    }
    if (g_model != nullptr) {
        llama_model_free(g_model);
        g_model = nullptr;
    }
    llama_backend_init();
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;
    g_model = llama_model_load_from_file(model_path, model_params);
    if (g_model == nullptr) {
        return 0;
    }
    g_loaded_path = model_path;
    return 1;
}

__attribute__((visibility("default"))) __attribute__((used))
const char* mediq_llama_generate(const char* model_path, const char* prompt, int max_tokens) {
    if (!mediq_llama_load_model(model_path) || g_model == nullptr) {
        return "";
    }

    const llama_vocab* vocab = llama_model_get_vocab(g_model);
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048;
    ctx_params.n_threads = 4;
    ctx_params.n_threads_batch = 4;

    llama_context* ctx = llama_init_from_model(g_model, ctx_params);
    if (!ctx) return "";

    const int n_prompt_max = strlen(prompt) + 32;
    std::vector<llama_token> tokens(n_prompt_max);
    int n_tokens = llama_tokenize(vocab, prompt, strlen(prompt), tokens.data(), tokens.size(), true, true);
    if (n_tokens < 0) {
        tokens.resize(-n_tokens);
        n_tokens = llama_tokenize(vocab, prompt, strlen(prompt), tokens.data(), tokens.size(), true, true);
    }
    tokens.resize(n_tokens);

    llama_batch batch = llama_batch_get_one(tokens.data(), tokens.size());
    if (llama_decode(ctx, batch) != 0) {
        llama_free(ctx);
        return "";
    }

    auto sparams = llama_sampler_chain_default_params();
    llama_sampler* smpl = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.25f));
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    g_last_output.clear();
    for (int i = 0; i < max_tokens; i++) {
        llama_token new_token_id = llama_sampler_sample(smpl, ctx, -1);
        if (llama_vocab_is_eog(vocab, new_token_id)) {
            break;
        }
        char buf[256];
        int n = llama_token_to_piece(vocab, new_token_id, buf, sizeof(buf), 0, true);
        if (n > 0) {
            g_last_output.append(buf, n);
        }
        if (g_last_output.find("<|im_end|>") != std::string::npos) {
            break;
        }
        batch = llama_batch_get_one(&new_token_id, 1);
        if (llama_decode(ctx, batch) != 0) {
            break;
        }
    }

    llama_sampler_free(smpl);
    llama_free(ctx);
    return g_last_output.c_str();
}

}
