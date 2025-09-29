<# ===============================================================================================
 Open Repo (PowerShell)
 Author: Sammy Hegab (Umicom Foundation)
 Licence: MIT

 PURPOSE
 - Quickly open a repo folder by slug in:
   * code      -> VS Code (default)
   * devenv    -> Visual Studio (opens .sln if found; else folder)
   * explorer  -> File Explorer
 =============================================================================================== #>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$Slug,
  [ValidateSet("code","devenv","explorer")]
  [string]$Editor = "code",
  [string]$Root   = "C:\dev"
)

$path = Join-Path $Root $Slug
if (-not (Test-Path $path)) { throw "Repo folder not found: $path" }

switch ($Editor) {
  "code"     { Start-Process code -ArgumentList @("-n", $path) }
  "devenv"   {
    $sln = Get-ChildItem -Path $path -Recurse -Filter *.sln -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sln) { Start-Process devenv $sln.FullName } else { Start-Process devenv $path }
  }
  "explorer" { Start-Process explorer $path }
}
# =========================================================================================
# End of file
