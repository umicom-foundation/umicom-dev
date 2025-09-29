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

<# =======================================================================
 Umicom Tools - Credits Banner Enforcer
 Maintainer: Umicom Foundation
Author: Sammy Hegab
  License: MIT
  WHAT THIS DOES 
 - Scans a tree and inserts a standard credits banner from a template
   into source files that are missing one.
 - Safe by default (dry-run). Use -Apply to write changes.
 - Compatible with Windows PowerShell 5.x and PowerShell 7+

 Usage examples:
   .\tools\enforce-credits.ps1 -Root C:\dev\umicom-dev -DryRun
   .\tools\enforce-credits.ps1 -Root C:\dev\umicom-dev -Apply -Verbose
======================================================================= #>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$Root,

  [string]$Template = "$PSScriptRoot\templates\CREDITS-HEADER.txt",

  # Write changes; otherwise just report (dry-run)
  [switch]$Apply,

  # File globs to include
  [string[]]$Include = @(
    '*.ps1','*.psm1','*.psd1','*.psd1',
    '*.c','*.h','*.cpp','*.hpp',
    '*.cs','*.java','*.go','*.rs','*.php',
    '*.js','*.ts','*.tsx','*.jsx','*.css','*.scss',
    '*.py','*.rb','*.sh','*.pl',
    '*.ini','*.toml','*.yml','*.yaml',
    '*.sql','*.md','*.xml','*.html'
  ),

  # Folder names to skip anywhere in the path
  [string[]]$ExcludeDirs = @(
    '.git','.github','.vs','.vscode',
    'bin','obj','build','out','dist','node_modules',
    'packages','coverage','artifacts','third_party','vendor','external'
  )
)

# ---- helpers -------------------------------------------------------------

function Get-NewLine {
  param([string]$text)
  if ($text -match "`r`n") { return "`r`n" }
  if ($text -match "`n")   { return "`n" }
  return "`r`n"
}

function Get-TemplateText {
  param([string]$Template)
  if (-not (Test-Path -LiteralPath $Template)) {
    throw "Template not found: $Template"
  }
  return (Get-Content -LiteralPath $Template -Raw)
}

function Wrap-Header {
  param(
    [string]$Ext,
    [string]$Body,
    [string]$nl
  )
  $ext = $Ext.ToLowerInvariant()

  # choose comment style
  if ($ext -in @('.ps1','.psm1','.psd1')) {
    return '<#' + $nl + $Body.TrimEnd() + $nl + '#>'
  }
  elseif ($ext -in @('.c','.h','.cpp','.hpp','.cs','.java','.go','.rs','.php','.js','.ts','.tsx','.jsx','.css','.scss','.sql','.xml','.html')) {
    return '/*' + $nl + $Body.TrimEnd() + $nl + '*/'
  }
  else {
    # default to line comments (e.g. .py, .sh, .yml, .toml, .md)
    $pref = ($Body -split "`r?`n") | ForEach-Object { '# ' + $_ }
    return ($pref -join $nl)
  }
}

function First-NonEmptyLine {
  param([string]$text)
  foreach ($line in ($text -split "`r?`n")) {
    $t = $line.Trim()
    if ($t.Length -gt 0) { return $t }
  }
  return ""
}

function Has-Header {
  param(
    [string]$FileText,
    [string]$Signature
  )
  $head = if ($FileText.Length -gt 4000) { $FileText.Substring(0,4000) } else { $FileText }
  return ($head.ToLowerInvariant().Contains($Signature.ToLowerInvariant()))
}

function Find-InsertionIndex {
  param([string]$text)
  # keep shebangs or XML prolog on first line
  if ($text -match '^(#!.*?)(\r?\n)')     { return $Matches[0].Length }
  if ($text -match '^(<\?xml.*?\?>)(\r?\n)') { return $Matches[0].Length }
  return 0
}

# ---- gather files --------------------------------------------------------

if (-not (Test-Path -LiteralPath $Root)) { throw "Root not found: $Root" }
$tpl      = Get-TemplateText -Template $Template
$signature = First-NonEmptyLine -text $tpl

# Build file list respecting Include globs
$files = @()
foreach ($pattern in $Include) {
  $files += Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue
}
# Remove excluded directories
$exRegex = [regex]::Escape(($ExcludeDirs -join '|')) -replace '\\\|','|'
$files = $files | Where-Object { $_.DirectoryName -notmatch "(^|\\)($exRegex)(\\|$)" }

$added = 0
$skipped = 0

foreach ($f in $files) {
  $path = $f.FullName
  $text = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
  if ($null -eq $text) { Write-Verbose "Skip (unreadable): $path"; $skipped++; continue }

  if (Has-Header -FileText $text -Signature $signature) {
    Write-Verbose "OK (has header): $path"
    $skipped++
    continue
  }

  $nl        = Get-NewLine -text $text
  $wrapped   = Wrap-Header -Ext $f.Extension -Body $tpl -nl $nl
  $insertion = Find-InsertionIndex -text $text

  # cross-version friendly (no ternary operators)
  if ($text.Length -gt 0) {
    $prefix = ""
    if ($insertion -gt 0) { $prefix = $nl }
    $before = if ($insertion -gt 0) { $text.Substring(0,$insertion) } else { "" }
    $after  = $text.Substring($insertion)
    $newText = $before + $prefix + $wrapped + $nl + $nl + $after
  } else {
    $newText = $wrapped + $nl + $nl
  }

  if ($Apply) {
    # Write UTF-8 without BOM (PS7 default) - consistent and friendly for Git
    Set-Content -LiteralPath $path -Value $newText -NoNewline -Encoding utf8
    Write-Host "[ADD] $path"
  } else {
    Write-Host "[WOULD ADD] $path"
  }
  $added++
}

Write-Host ""
if ($Apply) {
  Write-Host "Inserted header into $added file(s). Skipped $skipped file(s)."
} else {
  Write-Host "Dry-run: would insert header into $added file(s). Skipped $skipped file(s). Use -Apply to write."
}
