<#
=============================================================================
 Umicom Dev Tools - {FILENAME}
 Project: Umicom AuthorEngine AI / Workspace Utilities
 Purpose: Keep credits & licensing visible in every file.
 
 Â© {YEAR} Umicom Foundation - License: MIT
 Credits: Umicom Foundation engineering. 
 NOTE: Do not remove this credits banner. Keep credits in all scripts/sources.
=============================================================================
#>

Param(
  [Parameter(Mandatory=$true)][string]$Key
)
setx MISTRAL_API_KEY $Key | Out-Null
Write-Host "MISTRAL_API_KEY persisted. Restart your terminal or app."
