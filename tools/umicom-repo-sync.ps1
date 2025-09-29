<# ===============================================================================================
 Umicom Repo Sync (PowerShell)
 Author: Sammy Hegab (Umicom Foundation)
 Licence: MIT. (c) 2025 Umicom Foundation.

 PURPOSE
 - Read projects.json (slug, name, desc, private).
 - Ensure each repo exists on GitHub (org "umicom-foundation") with README (so main exists).
 - Ensure each repo exists locally under C:\dev\<slug>.
 - If local repo has no commits: create skeleton (README, LICENSE, .gitignore, .gitattributes, src\main.c),
   commit to MAIN, push, set upstream.
 - Idempotent: safe to re-run; skips what already exists.
 - Optional: after sync, prompt to run a one-time auto-commit sweep that stages/commits/pushes any
   pending changes across all local repos to main.

 HOUSE RULES
 - Always commit directly to "main" (no feature branches).
 - Include heavy, descriptive comments and credit headers in all files/scripts.

 REQUIREMENTS
 - Git + GitHub CLI (gh). Run once: gh auth login
 - Allow scripts: Set-ExecutionPolicy -Scope Process Bypass
 =============================================================================================== #>

[CmdletBinding()]
param(
  [string]$ConfigFile = "C:\dev\projects.json",
  [string]$Org        = "umicom-foundation",
  [string]$Root       = "C:\dev",
  [switch]$Public,
  [switch]$Private,
  [switch]$DryRun
)

Write-Host "Umicom Repo Sync - starting..." -ForegroundColor Cyan

# Environment checks
if (-not (Test-Path $ConfigFile)) { throw "Config file not found: $ConfigFile" }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git is not installed or not on PATH." }
if (-not (Get-Command gh  -ErrorAction SilentlyContinue)) { throw "GitHub CLI (gh) is not installed or not on PATH." }
& gh auth status 1>$null 2>$null
if ($LASTEXITCODE -ne 0) { throw "GitHub CLI is not authenticated. Run: gh auth login" }
if (-not (Test-Path $Root)) { New-Item -ItemType Directory -Path $Root | Out-Null }

# Load projects
$projects = Get-Content $ConfigFile -Raw | ConvertFrom-Json
if (-not $projects) { throw "No projects found in $ConfigFile" }

# Helper: skeleton writer (README, LICENSE, .gitignore, .gitattributes, src\main.c)
function New-UmicomSkeleton {
  param([string]$Path, [string]$Name, [string]$Desc)

  New-Item -ItemType Directory -Path $Path -Force | Out-Null
  Push-Location $Path

  foreach ($d in @("src","include","docs","scripts",".github\workflows")) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
  }

  $readmeTemplate = @'
# {0}

{1}

## Structure
- src/ - Source code (C/C++ unless project dictates otherwise)
- include/ - Public headers
- docs/ - Documentation, ADRs, design notes
- scripts/ - Development and build scripts
- .github/workflows/ - CI

## Author and Organisation
- Author: Sammy Hegab
- Organisation: Umicom Foundation
- Licence: MIT

House rule: commit directly to "main" (no branches). Keep code and scripts heavily commented.
'@
  $readme = [string]::Format($readmeTemplate, $Name, $Desc)
  Set-Content -Path README.md -Value $readme -Encoding UTF8

  $license = @'
MIT License

Copyright (c) YEAR Umicom Foundation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to do so, subject to the following conditions:

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
'@
  $license = $license -replace "YEAR", (Get-Date -Format yyyy)
  Set-Content -Path LICENSE -Value $license -Encoding UTF8

  $gitignore = @'
/build/
/out/
/dist/
/*.log
# CMake
CMakeFiles/
/CMakeCache.txt
cmake-build-*/
# Node (if web assets later)
/node_modules/
'@
  Set-Content -Path .gitignore -Value $gitignore -Encoding UTF8

  # Line ending normalization to avoid CRLF/LF noise across platforms
  $gitattributes = @'
*               text=auto
*.c             text eol=lf
*.h             text eol=lf
*.cpp           text eol=lf
*.hpp           text eol=lf
*.sh            text eol=lf
*.ps1           text eol=crlf
*.md            text eol=lf
*.json          text eol=lf
*.yaml          text eol=lf
*.yml           text eol=lf
*.svg           text eol=lf
*.ui            text eol=lf
*.css           text eol=lf

*.png           binary
*.jpg           binary
*.ico           binary
*.pdf           binary
'@
  Set-Content -Path .gitattributes -Value $gitattributes -Encoding UTF8

  $mainc = @'
/*
 * File: src/main.c
 * Author: Sammy Hegab (Umicom Foundation)
 * Purpose: Minimal C entry point to validate toolchains and CI.
 * Notes: This file is intentionally simple; expand per-project needs.
 */
#include <stdio.h>
int main(void) {
  puts("Hello from starter");
  return 0;
}
'@
  Set-Content -Path "src\main.c" -Value $mainc -Encoding UTF8

  Pop-Location
}

# Helper: remote repo existence
function Test-RepoExists {
  param([string]$Org, [string]$Slug)
  & gh repo view "$Org/$Slug" --json name 1>$null 2>$null
  return ($LASTEXITCODE -eq 0)
}

# Helper: create remote repo with README so main exists
function New-RemoteRepo {
  param([string]$Org, [string]$Slug, [string]$Name, [string]$Desc, [bool]$IsPrivate)

  $visibility = "--public"
  if ($IsPrivate) { $visibility = "--private" }

  & gh repo create "$Org/$Slug" $visibility --description "$Desc" --add-readme
  if ($LASTEXITCODE -ne 0) { throw "Failed to create remote repo: $Org/$Slug" }

  & gh api -X PATCH "repos/$Org/$Slug" -f has_wiki=false -f has_projects=false 1>$null
  & gh api -X PATCH "repos/$Org/$Slug" -f default_branch=main 1>$null
}

# Plan
$plan = foreach ($p in $projects) {
  $slug = $p.slug; $name = $p.name; $desc = $p.desc
  $isPrivate = [bool]$p.private
  if ($Public)  { $isPrivate = $false }
  if ($Private) { $isPrivate = $true  }

  $localPath = Join-Path $Root $slug
  $remoteExists = Test-RepoExists -Org $Org -Slug $slug
  $localExists  = Test-Path $localPath
  [pscustomobject]@{
    Slug=$slug; Name=$name; RemoteExists=$remoteExists; LocalExists=$localExists; Private=$isPrivate
  }
}

Write-Host ""
Write-Host "Plan:" -ForegroundColor Cyan
foreach ($row in $plan) {
  $tags = @()
  if ($row.RemoteExists) { $tags += "RemoteOK" } else { $tags += "CreateRemote" }
  if ($row.LocalExists)  { $tags += "LocalOK"  } else { $tags += "CloneOrInit" }
  Write-Host (" - {0} :: {1}" -f $row.Slug, ($tags -join ", "))
}

if ($DryRun) {
  Write-Host "`nDry run: exiting without changes." -ForegroundColor Yellow
  exit 0
}

# Execute
foreach ($p in $projects) {
  $slug = $p.slug; $name = $p.name; $desc = $p.desc
  $isPrivate = [bool]$p.private
  if ($Public)  { $isPrivate = $false }
  if ($Private) { $isPrivate = $true  }

  $localPath = Join-Path $Root $slug
  $remoteExists = Test-RepoExists -Org $Org -Slug $slug

  if (-not $remoteExists) {
    Write-Host "`nCreating remote: $Org/$slug ($name)..." -ForegroundColor Yellow
    New-RemoteRepo -Org $Org -Slug $slug -Name $name -Desc $desc -IsPrivate:$isPrivate
  } else {
    Write-Host "`nRemote exists: $Org/$slug" -ForegroundColor DarkGreen
  }

  if (-not (Test-Path $localPath)) {
    Write-Host "Cloning to $localPath ..." -ForegroundColor Yellow
    & gh repo clone "$Org/$slug" "$localPath" 1>$null
    if ($LASTEXITCODE -ne 0) {
      Write-Host "Clone failed (network or empty remote). Initialising locally..." -ForegroundColor Yellow
      New-Item -ItemType Directory -Path $localPath -Force | Out-Null
      Push-Location $localPath
      git init | Out-Null
      git branch -M main
      git remote add origin "https://github.com/$Org/$slug.git"
      Pop-Location
    }
  } else {
    Write-Host "Local exists: $localPath" -ForegroundColor DarkGreen
  }

  Push-Location $localPath
  if (-not (Test-Path ".git")) { git init | Out-Null; git branch -M main }

  $currentBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
  if (-not $currentBranch -or $currentBranch -eq "HEAD") {
    git checkout -B main | Out-Null
  } elseif ($currentBranch -ne "main") {
    git checkout main 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { git checkout -B main | Out-Null }
  }

  git rev-parse --verify HEAD 1>$null 2>$null
  $hasCommits = ($LASTEXITCODE -eq 0)

  if (-not $hasCommits) {
    Write-Host "Bootstrapping skeleton and initial commit..." -ForegroundColor Yellow
    New-UmicomSkeleton -Path $localPath -Name $name -Desc $desc
    git add .
    git commit -m "chore: bootstrap skeleton ($name) - main-only policy" | Out-Null
    if (-not (git remote)) { git remote add origin "https://github.com/$Org/$slug.git" }
    git push -u origin main
  } else {
    Write-Host "Repo has commits; pulling latest main (rebase)..." -ForegroundColor DarkGreen
    git pull --rebase origin main 2>$null
    if ($LASTEXITCODE -ne 0) {
      git branch --set-upstream-to=origin/main main 2>$null
      git pull --rebase origin main 2>$null
    }
  }
  Pop-Location
}

Write-Host "`nSync done. Main-only policy respected." -ForegroundColor Cyan

# Auto-commit sweep (optional)
$reply = Read-Host "Run auto-commit sweep now? (y/N)"
if ($reply -match "^(y|Y)$") {
  Write-Host "Auto-commit sweep started..." -ForegroundColor Cyan

  foreach ($p in $projects) {
    $localPath = Join-Path $Root $p.slug
    if (-not (Test-Path $localPath)) { continue }
    if (-not (Test-Path (Join-Path $localPath ".git"))) { continue }

    Push-Location $localPath

    $currentBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
    if (-not $currentBranch -or $currentBranch -eq "HEAD") {
      git checkout -B main 1>$null 2>$null
    } elseif ($currentBranch -ne "main") {
      git checkout main 1>$null 2>$null
      if ($LASTEXITCODE -ne 0) { git checkout -B main 1>$null 2>$null }
    }

    $status = git status --porcelain
    if ($status) {
      git add -A
      $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
      git commit -m "chore: autosave ($ts) - main-only policy"
      $hasRemote = git remote 2>$null
      if (-not $hasRemote) {
        git remote add origin "https://github.com/$Org/$($p.slug).git"
      }
      git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 1>$null 2>$null
      if ($LASTEXITCODE -ne 0) {
        git push -u origin main
      } else {
        git push origin main
      }
      Write-Host (" - Committed and pushed changes in {0}" -f $p.slug) -ForegroundColor Green
    } else {
      Write-Host (" - No changes in {0}" -f $p.slug)
    }

    Pop-Location
  }

  Write-Host "Auto-commit sweep complete." -ForegroundColor Cyan
} else {
  Write-Host "Skipped auto-commit sweep." -ForegroundColor Yellow
}

Write-Host "Umicom Repo Sync - finished."
# =========================================================================================