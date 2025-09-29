#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

<#
.SYNOPSIS
  enforce-credits.ps1 — Ensure every script/source file under a root contains the Umicom credit banner.

.DESCRIPTION
  * Reads a header template (tools\templates\CREDITS-HEADER.txt by default).
  * Injects the banner at the top of files that don't already contain a recognizable "Credits" header.
  * Only touches known-safe text formats (PowerShell, C/C++, headers, Python, shell, Markdown).
  * Defaults to Dry-Run; add -Apply to write changes.

.NOTES
  © 2025 Umicom Foundation — All rights reserved.
  Keep this header in all scripts / sources. Do not remove credits.

.PARAMETER Root
  The root folder to scan (e.g., C:\\dev\\umicom-dev\\tools). Defaults to current directory.

.PARAMETER Template
  Path to the header template. Tokens supported: {FILENAME} and {YEAR}.

.PARAMETER Apply
  Actually write changes. (Default is a dry-run with a report).

.EXAMPLE
  .\\enforce-credits.ps1 -Root C:\\dev\\umicom-dev\\tools -Apply

.EXAMPLE
  .\\enforce-credits.ps1 -Root C:\\dev\\umicom-dev\\tools -Template .\\templates\\CREDITS-HEADER.txt -Apply
#>

param(
  [string]$Root = (Get-Location).Path,
  [string]$Template = "$(Split-Path -Parent $PSCommandPath)\\templates\\CREDITS-HEADER.txt",
  [switch]$Apply
)

function Get-CommentWrappedHeader($ext, $body) {
  switch ($ext.ToLowerInvariant()) {
    ".ps1" { return ($body -split "`n" | ForEach-Object { '# ' + $_ }) -join "`r`n" }
    ".psm1" { return ($body -split "`n" | ForEach-Object { '# ' + $_ }) -join "`r`n" }
    ".psd1" { return ($body -split "`n" | ForEach-Object { '# ' + $_ }) -join "`r`n" }
    ".py"  { return ($body -split "`n" | ForEach-Object { '# ' + $_ }) -join "`r`n" }
    ".sh"  { return ($body -split "`n" | ForEach-Object { '# ' + $_ }) -join "`r`n" }
    ".c"   { return "/*`r`n$body`r`n*/" }
    ".h"   { return "/*`r`n$body`r`n*/" }
    ".cpp" { return "/*`r`n$body`r`n*/" }
    ".hpp" { return "/*`r`n$body`r`n*/" }
    ".md"  { return "<!--`r`n" + $body + "`r`n-->" }
    default { return $null }
  }
}

$rootPath = (Resolve-Path -LiteralPath $Root).Path

if (-not (Test-Path -LiteralPath $Template)) {
  throw "Header template not found: $Template"
}
$tpl = Get-Content -LiteralPath $Template -Raw -Encoding UTF8

$extensions = @(".ps1",".psm1",".psd1",".c",".h",".cpp",".hpp",".py",".sh",".md")
$skipDirs   = @(".git","build","build-vs","bin","obj",".cache",".vscode",".vs")

$files = Get-ChildItem -LiteralPath $rootPath -Recurse -File |
  Where-Object {
    $extOk = $extensions -contains $_.Extension.ToLowerInvariant()
    $inSkip = $false
    $p = $_.DirectoryName
    foreach ($s in $skipDirs) { if ($p -like "*\0\*" -f $s) { $inSkip=$true; break } }
    return $extOk -and (-not $inSkip)
  }

$changed = 0
foreach ($f in $files) {
  $text = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
  if ($text -match '(?im)^\s*(#|\/\*|<!--).*(credits|umicom).*(\*\/|-->)?') {
    Write-Host "[ok]    $($f.FullName) — credits present"
    continue
  }

  $headerBody = $tpl.Replace("{FILENAME}", $f.Name).Replace("{YEAR}", "2025")
  $wrapped = Get-CommentWrappedHeader $f.Extension $headerBody
  if (-not $wrapped) {
    Write-Host "[skip]  $($f.FullName) — unsupported extension '$($f.Extension)'"
    continue
  }

  # Keep shebangs safe; insert after a shebang if present
  $insertion = 0
  if ($text -match '^(#!.*)') { $insertion = ($Matches[0].Length) }

  $newText = ($text.Length -gt 0) ? ($text.Insert($insertion, ($insertion -gt 0 ? "`r`n" : "") + $wrapped + "`r`n`r`n")) : ($wrapped + "`r`n")
  if ($Apply) {
    Set-Content -LiteralPath $f.FullName -Value $newText -Encoding UTF8
    Write-Host "[fixed] $($f.FullName) — header inserted"
    $changed++
  } else {
    Write-Host "[would] $($f.FullName) — would insert header"
  }
}

if ($Apply) {
  Write-Host "Done. Files changed: $changed"
} else {
  Write-Host "Dry-run complete. Files that would change: $changed"
  Write-Host "Re-run with -Apply to write changes."
}
