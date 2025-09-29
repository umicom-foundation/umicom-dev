# UAEngine Mistral Backend Design

**Objective:** Plug a Mistral-backed LLM into UAEngine’s tiny LLM façade without breaking other providers.

### Interface (existing)

```c
typedef struct ueng_llm_ctx ueng_llm_ctx;
ueng_llm_ctx *ueng_llm_open(const char *model_path, int ctx_tokens, char *err, size_t errsz);
int ueng_llm_prompt(ueng_llm_ctx *ctx, const char *prompt, char *out, size_t outsz);
void ueng_llm_close(ueng_llm_ctx *ctx);
```

For the Mistral backend, `model_path` is interpreted as the **model name** (e.g., `mistral-small-latest` or `codestral-latest`).

### Config

- Read `MISTRAL_API_KEY` (required) and optional `UENG_MISTRAL_BASE_URL` (default `https://api.mistral.ai`).
- Allow overriding the model via `UENG_MISTRAL_MODEL` (defaults to the value passed to `ueng_llm_open`).

### HTTP

- Use libcurl with `Authorization: Bearer <key>` and `Content-Type: application/json`.
- Endpoint: `POST {base}/v1/chat/completions`.
- Body:
```json
{
  "model": "mistral-small-latest",
  "messages": [{"role":"user","content":"<prompt>"}],
  "temperature": 0.2,
  "max_tokens": 512
}
```

### Minimal JSON Parsing

To keep dependencies light, the sample implementation just extracts the first `content` occurrence in the response. For production, swap in a proper JSON parser (yyjson/cJSON).
