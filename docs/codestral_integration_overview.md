# Codestral Integration Overview

**Goal:** Add Mistral AI (Codestral) to Umicom projects for both *editor infill* (FIM) and *chat-style completions*.

- UAEngine (CLI): uses **Chat Completions** for structured prompts, scaffolding, and narrative content.
- Umicom Studio IDE: uses **FIM** for inline code completion between a prefix and suffix.

## Security

- Do **not** hardcode keys.
- Use `MISTRAL_API_KEY` environment variable or a `.env.local` file (git-ignored).
- Never print secrets in logs.
- Optionally set `UENG_MISTRAL_BASE_URL` if you route via a proxy/gateway; default is `https://api.mistral.ai`.

## Endpoints

- Chat: `POST /v1/chat/completions`
- FIM : `POST /v1/fim/completions`
- Models discovery: `GET /v1/models`

## Dependencies

- **libcurl** for HTTPS calls.
- CMake 3.16+ recommended.
- On Windows: install curl binaries/SDK or use vcpkg: `vcpkg install curl`.
