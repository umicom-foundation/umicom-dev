# Studio FIM Design (Umicom Studio IDE)

**Objective:** Provide fast *Fill-In-the-Middle* (infill) completions in the editor.

- The editor splits the buffer into `prefix` (before cursor) and `suffix` (after cursor).
- Call Codestral FIM: `POST /v1/fim/completions` with JSON: `{model, prompt, suffix, max_tokens, temperature}`.
- Streamed mode can be added later (websocket/server-sent events).

### Suggested UX

- A statusbar language picker `{LANG}`.
- Auto-detect language from active file extension.
- One-click "Infill" action bound to `Ctrl+I` (Windows/Linux) / `Cmd+I` (macOS).
- Configurable max tokens and temperature per language.

### Error Handling

- On HTTP non-2xx: show a toast with `status code + short message`.
- On empty key: prompt the user to set `MISTRAL_API_KEY`.
- On timeouts: back off and retry once.
