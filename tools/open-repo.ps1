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
  [Parameter(Mandatory=$true)][string]$Slug,
  [string]$Root = "C:\dev",
  [ValidateSet("code","devenv","explorer")] [string]$Editor = "code",
  [string]$Branch,
  [switch]$EnsureFetch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$path = Join-Path $Root $Slug
if (-not (Test-Path $path)) {
  throw "Repo folder not found: $path"
}

# Optional branch checkout
if ($Branch) {
  if ($EnsureFetch) {
    & git -C $path fetch --all --prune
  }
  & git -C $path rev-parse --verify $Branch 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    & git -C $path checkout $Branch
  } else {
    Write-Warning "Branch '$Branch' not found locally; trying 'origin/$Branch' ..."
    & git -C $path checkout -b $Branch origin/$Branch 2>$null
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "Could not checkout '$Branch'. Continuing without branch change."
    }
  }
}

switch ($Editor) {
  "code" {
    # Prefer reusing a window
    Start-Process -FilePath "code" -ArgumentList @("-r","`"$path`"") -WorkingDirectory $path
  }
  "devenv" {
    # Try to find a solution
    $sln = Get-ChildItem -Path $path -Recurse -Filter *.sln -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sln) {
      Start-Process -FilePath "devenv" -ArgumentList "`"$($sln.FullName)`"" -WorkingDirectory $path
    } else {
      Write-Warning "No .sln file found. Opening the folder in Code instead."
      Start-Process -FilePath "code" -ArgumentList @("-r","`"$path`"") -WorkingDirectory $path
    }
  }
  "explorer" {
    Start-Process -FilePath "explorer.exe" -ArgumentList "`"$path`""
  }
}
