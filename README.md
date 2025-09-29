# Umicom Ã— Codestral (Mistral AI) â€” Integration Pack
Date: 2025-09-28

This bundle adds **Codestral** support across your Umicom repos with secure key handling, C/CMake code, test scripts, and detailed documentation.

Repos covered:
- **umicom-authorengine-ai** (UAEngine CLI): add a **Mistral backend** (`llm_mistral.c`) using the Chat Completions API.
- **umicom-studio-ide**: provide a minimal **FIM (Fillâ€‘Inâ€‘theâ€‘Middle)** integration (`studio_codestral_fim.c`) designed for editor autocomplete/infill.
- Common scripts for environment setup and quick cURL-based tests.

> Keys are **never** committed. Use `MISTRAL_API_KEY` in your shell environment or `.env.local` (gitâ€‘ignored).

## Quick Start

1) Set your key:
- PowerShell (Windows):
```powershell
setx MISTRAL_API_KEY "sk-..."
# restart shell/app
```
- Bash (Linux/macOS):
```bash
echo 'export MISTRAL_API_KEY=sk-...' >> ~/.bashrc
source ~/.bashrc
```

2) Test Chat endpoint:
```bash
./scripts/test-codestral-chat.sh
```

3) Test FIM endpoint:
```bash
./scripts/test-codestral-fim.sh
```

4) Build UAEngine with Mistral backend (libcurl required):
```bash
cd umicom-authorengine-ai
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build . -j
```

5) Build Studio IDE backend stub (FIM demo):
```bash
cd umicom-studio-ide
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build . -j
```

See repoâ€‘specific READMEs inside each folder for details.


---

## OpenAPI Schema (Mistral)

- `third_party/api-schemas/mistral/openapi.yaml` â€” the API contract used for docs and codegen.
- Local viewers: open `umicom-authorengine-ai/docs/api/mistral/index.html` or `umicom-studio-ide/docs/api/mistral/index.html`.
- Sync script: `./scripts/sync-mistral-schema.sh` (or `.ps1`).
- Codegen scripts (optional):  
  - `./scripts/generate/openapi_codegen_c.sh` / `.ps1`  
  - `./scripts/generate/openapi_codegen_cpp.sh` / `.ps1`

> Codegen is optional â€” our hand-written `libcurl` backends (Chat + FIM) are already included and heavily commented.
