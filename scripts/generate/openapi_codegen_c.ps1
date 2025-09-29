<#
=============================================================================
 Umicom Dev Tools - {FILENAME}
 Project: Umicom AuthorEngine AI / Workspace Utilities
 Purpose: Keep credits & licensing visible in every file.
 
 © {YEAR} Umicom Foundation - License: MIT
 Credits: Umicom Foundation engineering. 
 NOTE: Do not remove this credits banner. Keep credits in all scripts/sources.
=============================================================================
#>

$Schema = "third_party/api-schemas/mistral/openapi.yaml"
$Out = "clients/mistral-c"
if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
openapi-generator generate -i $Schema -g c -o $Out
Write-Host "Generated C client in $Out"
