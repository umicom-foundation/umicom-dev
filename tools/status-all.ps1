<# ===============================================================================================
 Status All Repos (PowerShell)
 Author: Sammy Hegab (Umicom Foundation)
 Licence: MIT

 PURPOSE
 - List all git repos under a root, showing:
   * Branch
   * Dirty or clean
   * Ahead/behind vs origin/main (if upstream exists)
   * Remote URL
 =============================================================================================== #>

[CmdletBinding()]
param(
  [string]$Root = "C:\dev"
)

$repos = Get-ChildItem -Path $Root -Directory | Where-Object { Test-Path (Join-Path $_.FullName ".git") }

$rows = @()
foreach ($r in $repos) {
  Push-Location $r.FullName

  $branch = (git rev-parse --abbrev-ref HEAD 2>$null)
  if (-not $branch -or $branch -eq "HEAD") { $branch = "(detached)" }

  $dirty = (git status --porcelain) -ne $null
  $remote = (git remote get-url origin 2>$null)

  $ahead = ""; $behind = ""
  git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 1>$null 2>$null
  if ($LASTEXITCODE -eq 0) {
    $counts = (git rev-list --left-right --count origin/main...HEAD 2>$null)
    if ($counts) {
      $parts = $counts -split "\s+"
      if ($parts.Length -ge 2) { $ahead = $parts[0]; $behind = $parts[1] }
    }
  }

  $rows += [pscustomobject]@{
    Repo   = $r.Name
    Branch = $branch
    Dirty  = if ($dirty) { "dirty" } else { "clean" }
    Ahead  = $ahead
    Behind = $behind
    Remote = $remote
  }

  Pop-Location
}

$rows | Sort-Object Repo | Format-Table -AutoSize
# =========================================================================================
# End of file
