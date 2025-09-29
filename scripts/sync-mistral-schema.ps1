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
  [string]$Source = "third_party/api-schemas/mistral/openapi.yaml"
)
if (!(Test-Path $Source)) { Write-Error "Spec not found: $Source"; exit 1 }
$Ae = "umicom-authorengine-ai/docs/api/mistral"
$Studio = "umicom-studio-ide/docs/api/mistral"
New-Item -ItemType Directory -Force -Path $Ae | Out-Null
New-Item -ItemType Directory -Force -Path $Studio | Out-Null
Copy-Item $Source -Destination (Join-Path $Ae "openapi.yaml") -Force
Copy-Item $Source -Destination (Join-Path $Studio "openapi.yaml") -Force
Write-Host "Synced to: $Ae and $Studio"
