# Mistral / Codestral OpenAPI Schema

This folder mirrors the official Mistral API spec for local docs, validation, and client code generation.

- Canonical file: `third_party/api-schemas/mistral/openapi.yaml`
- Repo viewers:
  - `umicom-authorengine-ai/docs/api/mistral/index.html`
  - `umicom-studio-ide/docs/api/mistral/index.html`

## Validate / Lint
```bash
npx @redocly/cli lint third_party/api-schemas/mistral/openapi.yaml
# or
npx swagger-cli validate third_party/api-schemas/mistral/openapi.yaml
```

## Generate Clients (optional)
See scripts under `scripts/generate/` to produce C/C++ clients with OpenAPI Generator.
