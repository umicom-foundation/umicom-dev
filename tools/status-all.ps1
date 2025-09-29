<# =================================================================================================
 Umicom Dev – Status Across All Repos (with submodule awareness)
 Author: Sammy Hegab  |  Organisation: Umicom Foundation
 License: MIT

 WHAT THIS DOES
  - Scans a root folder for Git repositories (each immediate subfolder that contains a ".git").
  - For each repo, prints:
       Repo   : folder name
       Branch : current branch (or "detached")
       Dirty  : clean / dirty
       Ahead  : commits ahead of upstream (if any)
       Behind : commits behind upstream (if any)
       Remote : origin URL (if any)
       Submods: submodule summary:
                • "none"  -> repo has no submodules
                • "clean" -> all submodules clean & initialized
                • "+:N"   -> N submodules have local modifications (new commits)        (git submodule status -> '+')
                • "-:N"   -> N submodules are not initialized                            (git submodule status -> '-')
                • "U:N"   -> N submodules have merge conflicts                           (git submodule status -> 'U')
                • "*parent-dirty" -> parent shows submodule as modified (likely untracked content)

 WHY
  - Previously, a submodule with untracked junk (e.g., accidental nested clone or build artefacts)
    made the parent repo appear "dirty" with no obvious files listed. This script highlights that.

 USAGE
   PS> C:\dev\umicom-dev\tools\status-all.ps1 -Root C:\dev
   PS> .\status-all.ps1 -Root "D:\work" -IncludeRoot   # also checks the root itself if it's a repo

 NOTES
  - Compatible with Windows PowerShell 5.x and PowerShell 7+.
  - We heavily comment by house rule.
  - No external modules required; only "git" must be on PATH.

 HOUSE RULES
  - Commit directly to main (no branches).
  - Heavily commented scripts and source files.

================================================================================================= #>

[CmdletBinding()]
param(
  # The root folder to scan for repositories (each direct child with a ".git" is treated as a repo)
  [string]$Root = "C:\dev",

  # Also check the root itself if it happens to be a Git repo
  [switch]$IncludeRoot
)

$ErrorActionPreference = "Stop"

#--- Helper: run a git command inside a repo path and capture output/exit code ---------------------
function Invoke-Git {
  param(
    [Parameter(Mandatory=$true)][string]$RepoPath,
    [Parameter(Mandatory=$true)][string[]]$Args
  )
  Push-Location $RepoPath
  try {
    $out = & git @Args 2>$null
    $code = $LASTEXITCODE
    return @{ Out = $out; Code = $code }
  } finally {
    Pop-Location
  }
}

#--- Helper: detect if a folder is a git repo (worktree) ------------------------------------------
function Test-IsGitRepo {
  param([string]$Path)
  return (Test-Path (Join-Path $Path '.git'))
}

#--- Build the list of candidate repos ------------------------------------------------------------
$repos = @()
if ($IncludeRoot -and (Test-IsGitRepo -Path $Root)) {
  $repos += (Get-Item -LiteralPath $Root)
}
$repos += Get-ChildItem -LiteralPath $Root -Directory |
  Where-Object { Test-IsGitRepo -Path $_.FullName }

#--- Nothing to do? -------------------------------------------------------------------------------
if (-not $repos) {
  Write-Host "No Git repositories found under: $Root" -ForegroundColor Yellow
  return
}

#--- Inspect each repo ----------------------------------------------------------------------------
$rows = foreach ($r in $repos) {
  $path = $r.FullName
  $name = $r.Name

  # Current branch (or 'detached')
  $branch = (Invoke-Git -RepoPath $path -Args @('rev-parse','--abbrev-ref','HEAD')).Out
  if (-not $branch) { $branch = 'detached' }

  # Dirty (any changes incl. untracked)
  $porcelain = (Invoke-Git -RepoPath $path -Args @('status','--porcelain','-uall')).Out
  $dirty = [bool]($porcelain -and $porcelain.Length -gt 0)
  $dirtyText = if ($dirty) { 'dirty' } else { 'clean' }

  # Upstream (tracking) ref and ahead/behind counts
  $up = (Invoke-Git -RepoPath $path -Args @('rev-parse','--abbrev-ref','--symbolic-full-name','@{u}')).Out
  $ahead = 0; $behind = 0
  if ($up) {
    # Count commits only in upstream (behind) and only in HEAD (ahead)
    $counts = (Invoke-Git -RepoPath $path -Args @('rev-list','--left-right','--count',"$up...HEAD")).Out
    if ($counts -match '^\s*(\d+)\s+(\d+)\s*$') {
      $behind = [int]$Matches[1]
      $ahead  = [int]$Matches[2]
    }
  }

  # Remote origin URL (may be empty)
  $remote = (Invoke-Git -RepoPath $path -Args @('config','--get','remote.origin.url')).Out

  # ---- Submodule summary ------------------------------------------------------------------------
  # Determine declared submodule paths (if any), via .gitmodules
  $subPaths = @()
  $gm = Join-Path $path '.gitmodules'
  if (Test-Path $gm) {
    $cfg = (Invoke-Git -RepoPath $path -Args @('config','-f','.gitmodules','--get-regexp','path'))
    if ($cfg.Code -eq 0 -and $cfg.Out) {
      foreach ($line in ($cfg.Out -split "`r?`n")) {
        if ($line -match '^\S+\s+(.+)$') { $subPaths += $Matches[1].Trim() }
      }
    }
  }

  # Get "git submodule status --recursive" to classify each submodule line by leading char
  $subStatusOut = (Invoke-Git -RepoPath $path -Args @('submodule','status','--recursive')).Out
  $submodsSummary = 'none'
  if ($subPaths.Count -gt 0) {
    if (-not $subStatusOut) {
      # There are declared submodules but none initialized -> treat as uninitialized
      $submodsSummary = '-:' + $subPaths.Count
    } else {
      $plus = 0; $dash = 0; $conf = 0; $space = 0
      foreach ($ln in ($subStatusOut -split "`r?`n" | Where-Object { $_ -ne '' })) {
        $c = $ln[0]
        switch ($c) {
          '+' { $plus++ }         # local modifications / new commits in submodule
          '-' { $dash++ }         # not initialized
          'U' { $conf++ }         # merge conflict
          ' ' { $space++ }        # up-to-date
          default { }             # ignore others
        }
      }

      if ($plus -eq 0 -and $dash -eq 0 -and $conf -eq 0) {
        $submodsSummary = 'clean'
      } else {
        # Build compact summary like "+:1 -:2 U:1"
        $parts = @()
        if ($plus -gt 0) { $parts += "+:$plus" }
        if ($dash -gt 0) { $parts += "-:$dash" }
        if ($conf -gt 0) { $parts += "U:$conf" }
        $submodsSummary = ($parts -join ' ')
      }
    }

    # Extra: detect parent showing submodule as modified (often due to UNTRACKED content inside)
    # We compare porcelain lines for " M <subpath>" against declared submodule paths.
    if ($porcelain) {
      $parentSubDirty = $false
      foreach ($pl in ($porcelain -split "`r?`n")) {
        if ($pl -match '^\s*M\s+(.+)$') {
          $p = $Matches[1].Trim()
          if ($subPaths -contains $p) { $parentSubDirty = $true; break }
        }
      }
      if ($parentSubDirty) {
        # Append a hint marker – this is the “(untracked content)” type of situation
        if ($submodsSummary -eq 'clean') { $submodsSummary = '' }
        if ($submodsSummary -and $submodsSummary -ne 'none') {
          $submodsSummary += ' '
        }
        $submodsSummary += '*parent-dirty'
      }
    }
  }

  [PSCustomObject]@{
    Repo    = $name
    Branch  = $branch
    Dirty   = $dirtyText
    Ahead   = $ahead
    Behind  = $behind
    Remote  = $remote
    Submods = $submodsSummary
  }
}

#--- Output ---------------------------------------------------------------------------------------
$rows | Sort-Object Repo | Format-Table Repo, Branch, Dirty, Ahead, Behind, Remote, Submods -AutoSize
# (Note: Format-Table is used here for nice column alignment; piping to Out-GridView is also an option)
# (Note: we could use a calculated property to truncate Remote URLs, but decided against it for full visibility)
# (Note: if you want raw objects for further processing, just output $rows instead of piping to Format-Table)

#--- End of script --------------------------------------------------------------------------------
