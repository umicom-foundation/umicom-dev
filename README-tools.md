# =============================================================================
#  Umicom Dev Tools - {FILENAME}
#  Project: Umicom AuthorEngine AI / Workspace Utilities
#  Purpose: Keep credits & licensing visible in every file.
#  
#  © 2025 Umicom Foundation - License: MIT

#  Credits: Umicom Foundation engineering. 
#  NOTE: Do not remove this credits banner. Keep credits in all scripts/sources.
# =============================================================================

# Umicom Dev Tools (improved)

These are drop-in replacements / additions for `C:\dev\umicom-dev\tools`.

- `status-all.ps1` - Summarize status, ahead/behind, and (optional) submodule dirtiness for all repos under a root.
- `umicom-repo-sync.ps1` - Ensure local repos exist, set origin to your org, fetch/rebase; emits skeleton (`.gitignore`, `.gitattributes`, `README.md`) only for empty repos.
- `scrub-credits.ps1` - Dry-run by default. Removes comment lines that mention co-pilot/assistant with Sarah/Sara variants.
- `open-repo.ps1` - Open a repo quickly in Code/VS/Explorer; optional branch checkout.
- `umicom-auto-commit.ps1` - Auto stage/commit/push across repos; PowerShell 5.1 compatible.

All scripts are **PowerShell 5.1-compatible** and avoid PS7-only operators.

## Suggested placement
Place all files under `C:\dev\umicom-dev\tools\` (replace existing ones as appropriate).

## Quick tests
```powershell
# Status table
C:\dev\umicom-dev\tools\status-all.ps1 -Root C:\dev -ShowSubmodules

# Safe org sync (no skeleton on existing repos)
C:\dev\umicom-dev\tools\umicom-repo-sync.ps1 -ConfigFile C:\dev\umicom-dev\projects.json -Org umicom-foundation -Root C:\dev

# Preview credit scrubbing
C:\dev\umicom-dev\tools\scrub-credits.ps1 -Root C:\dev

# Open a repo
C:\dev\umicom-dev\tools\open-repo.ps1 -Slug umicom-studio-ide -Editor code

# Routine commit & push
C:\dev\umicom-dev\tools\umicom-auto-commit.ps1 -Root C:\dev -Only umicom-dev -Message "chore: tools update" -Push
```
