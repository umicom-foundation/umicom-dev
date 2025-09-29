<# =====================================================================
 Umicom Foundation - Standard Credits Header Enforcer
 Author: Sammy Hegab
 File: tools/enforce-credits.ps1

 PURPOSE
   Inserts (or replaces) a standardized ASCII-only credits header at the
   top of source files. Preserves each file's original encoding and line
   endings. Positions the header below a shebang (#!) when present.

 USAGE
   # Dry-run (no writes)
   .\tools\enforce-credits.ps1 -Root C:\dev

   # Apply (write changes)
   .\tools\enforce-credits.ps1 -Root C:\dev -Apply

   # Narrow to extensions or exclude folders/files
   .\tools\enforce-credits.ps1 -Root C:\dev -Apply `
     -IncludeExt .ps1,.psm1,.c,.h,.cpp,.hpp,.js,.ts,.py,.sh `
     -ExcludePath '\.git','\bthird_party\b','\bnode_modules\b'

 NOTES
   - ASCII-only header to avoid mojibake.
   - No “Sarah” or co-pilot references included.
   - Existing headers matching our sentinel lines are replaced.
   - Skips formats without comments (e.g., JSON) and binary files.

 License: MIT (see LICENSE)
 Copyright (c) 2025 Umicom Foundation
 Do not remove this header.
===================================================================== #>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory=$true)]
  [string]$Root,

  [switch]$Apply,

  # Which file extensions to consider (default: common source/script/doc types)
  [string[]]$IncludeExt = @(
    '.ps1','.psm1','.psd1',
    '.bat','.cmd',
    '.sh','.bash',
    '.py',
    '.c','.h','.cpp','.hpp','.cc',
    '.cs','.java','.go','.php',
    '.js','.ts',
    '.md','.rst','.yml','.yaml'
  ),

  # Regex fragments to exclude paths (matched against full path, case-insensitive)
  [string[]]$ExcludePath = @('\.git','\bbin\b','\bobj\b','\bnode_modules\b','\b.vscode\b','\b\.vs\b','\bbuild\b'),

  # Optional: override the default ASCII header lines
  [string[]]$HeaderLines = @(
    '=====================================================================',
    ' Umicom Foundation - Standard Credits Header',
    ' Project: (set as appropriate)',
    ' Purpose: (briefly describe this file)',
    ' License: MIT (see LICENSE)',
    ' Copyright (c) 2025 Umicom Foundation',
    ' Author: Sammy Hegab',
    ' Do not remove this header.',
    '====================================================================='
  )
)

# ------------------------------
# Utility: should we skip a file?
# ------------------------------
function Should-SkipFile([string]$path, [string[]]$excludeRegexes) {
  foreach ($rx in $excludeRegexes) {
    if ($path -imatch $rx) { return $true }
  }
  return $false
}

# -------------------------------------
# Comment style selection by extension
# -------------------------------------
function Get-CommentStyle([string]$ext) {
  $ext = $ext.ToLowerInvariant()
  switch ($ext) {
    # Single-line '#'
    { $_ -in '.ps1','.psm1','.psd1','.py','.sh','.bash','.yml','.yaml' } {
      return [pscustomobject]@{ Kind='line'; LinePrefix='# '; BlockOpen=$null; BlockPrefix=$null; BlockClose=$null }
    }
    # Batch files
    { $_ -in '.bat','.cmd' } {
      return [pscustomobject]@{ Kind='line'; LinePrefix=':: '; BlockOpen=$null; BlockPrefix=$null; BlockClose=$null }
    }
    # Block comments /* ... */
    { $_ -in '.c','.h','.cpp','.hpp','.cc','.cs','.java','.js','.ts','.go','.php' } {
      return [pscustomobject]@{ Kind='block'; LinePrefix=$null; BlockOpen='/*'; BlockPrefix=' * '; BlockClose=' */' }
    }
    # Markdown/HTML-style comment
    { $_ -in '.md','.rst' } {
      return [pscustomobject]@{ Kind='block'; LinePrefix=$null; BlockOpen='<!--'; BlockPrefix='  '; BlockClose='-->' }
    }
    default {
      return $null
    }
  }
}

# -------------------------------------------------
# Build a header string in the requested style
# -------------------------------------------------
function Build-Header([pscustomobject]$style, [string[]]$lines, [string]$nl) {
  if ($style.Kind -eq 'line') {
    $body = ($lines | ForEach-Object { $style.LinePrefix + $_ }) -join $nl
    return $body + $nl + $nl
  } else {
    $top    = $style.BlockOpen + $nl
    $middle = ($lines | ForEach-Object { $style.BlockPrefix + $_ }) -join $nl
    $bot    = $nl + $style.BlockClose + $nl + $nl
    return $top + $middle + $bot
  }
}

# -------------------------------------------------
# Detect newline style from existing text
# -------------------------------------------------
function Detect-Newline([string]$text) {
  if ($text -match "`r`n") { return "`r`n" }
  elseif ($text -match "`n") { return "`n" }
  else { return "`r`n" }
}

# -------------------------------------------------
# Minimal binary / very large file guard
# -------------------------------------------------
function Is-ProbablyBinary([byte[]]$bytes) {
  if ($bytes.Length -eq 0) { return $false }
  $check = [Math]::Min(4096, $bytes.Length)
  for ($i=0; $i -lt $check; $i++) {
    if ($bytes[$i] -eq 0) { return $true } # NUL often indicates binary
  }
  return $false
}

# -------------------------------------------------
# Read file preserving encoding + detect BOM/newline
# -------------------------------------------------
function Read-File([string]$path) {
  $bytes = [System.IO.File]::ReadAllBytes($path)
  $encoding = $null
  # BOM detection
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $encoding = New-Object System.Text.UTF8Encoding($true)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes,3,$bytes.Length-3)
  } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
    $encoding = [System.Text.Encoding]::Unicode # UTF-16 LE BOM
    $text = $encoding.GetString($bytes,2,$bytes.Length-2)
  } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
    $encoding = [System.Text.Encoding]::BigEndianUnicode # UTF-16 BE BOM
    $text = $encoding.GetString($bytes,2,$bytes.Length-2)
  } else {
    # No BOM: assume UTF-8 (no BOM). If the file is actually ANSI, ASCII-only header is still safe.
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $text = $encoding.GetString($bytes)
  }
  $nl = Detect-Newline $text
  return [pscustomobject]@{
    Text=$text; Encoding=$encoding; Newline=$nl; HasBOM=($encoding.Preamble.Length -gt 0)
  }
}

# -------------------------------------------------
# Write file using same encoding & BOM
# -------------------------------------------------
function Write-File([string]$path, [string]$text, $encoding) {
  $preamble = $encoding.Preamble
  $body = $encoding.GetBytes($text)
  if ($preamble -and $preamble.Length -gt 0) {
    $out = New-Object byte[] ($preamble.Length + $body.Length)
    [Array]::Copy($preamble, 0, $out, 0, $preamble.Length)
    [Array]::Copy($body, 0, $out, $preamble.Length, $body.Length)
  } else {
    $out = $body
  }
  [System.IO.File]::WriteAllBytes($path, $out)
}

# -------------------------------------------------
# Find insert position (after shebang if present)
# -------------------------------------------------
function Find-InsertIndex([string]$text) {
  if ($text -match '^(#!.*?)(\r?\n)') {
    return ($matches[0]).Length
  }
  return 0
}

# -------------------------------------------------
# Does the file already have our header near the top?
# Also: find/replace a previously inserted (possibly garbled) header.
# We look within the first ~80 lines for BOTH sentinel strings.
# -------------------------------------------------
function Remove-ExistingHeader([string]$text, [string]$nl) {
  $maxScan = 80
  $lines = $text -split "`r?`n"
  $scanTo = [Math]::Min($maxScan, $lines.Count)
  $slice = $lines[0..([Math]::Max(0,$scanTo-1))] -join $nl

  $hasSentinel1 = ($slice -match 'Umicom Foundation - Standard Credits Header')
  $hasSentinel2 = ($slice -match '\. Do not remove this header\.')

  if ($hasSentinel1 -and $hasSentinel2) {
    # Remove from the first occurrence of our block opener line to the end of the block.
    # We support any of the three styles: line '#', C-style, or HTML.
    $patterns = @(
      '(?s)^(?:#\s*)?=+[\s\S]*?Author: Sammy Hegab remove this header\.[\s\S]*?(?:\r?\n){2}',
      '(?s)^/\*[\s\S]*?Author: Sammy Hegab remove this header\.[\s\S]*?\*/(?:\r?\n){1,2}',
      '(?s)^<!--[\s\S]*?Author: Sammy Hegab remove this header\.[\s\S]*?-->(?:\r?\n){1,2}'
    )
    foreach ($rx in $patterns) {
      $newText = [System.Text.RegularExpressions.Regex]::Replace($text, $rx, '', 'IgnoreCase, Multiline')
      if ($newText -ne $text) { return $newText }
    }
  }
  return $text
}

# ----------------
# Main walk
# ----------------
$rootFull = (Resolve-Path $Root).ProviderPath
$all = Get-ChildItem -LiteralPath $rootFull -Recurse -File -ErrorAction SilentlyContinue

$changed = 0
$skipped = 0

foreach ($f in $all) {
  try {
    $ext = [System.IO.Path]::GetExtension($f.Name)
    if (-not ($IncludeExt -contains $ext)) { $skipped++; continue }

    $full = $f.FullName
    if (Should-SkipFile $full $ExcludePath) { $skipped++; continue }

    # quick binary guard
    $probe = [System.IO.File]::ReadAllBytes($full)
    if (Is-ProbablyBinary $probe) { $skipped++; continue }

    $style = Get-CommentStyle $ext
    if (-not $style) { $skipped++; continue }

    $file = Read-File $full
    $text = $file.Text
    $nl   = $file.Newline

    # Replace a previously inserted header (even if garbled)
    $text = Remove-ExistingHeader $text $nl

    # Check if a header already exists by sentinel (after removal attempt, it shouldn’t)
    $headCheck = ($text -split "`r?`n")[0..([Math]::Min(20,($text -split "`r?`n").Count-1))] -join $nl
    if ($headCheck -match 'Umicom Foundation - Standard Credits Header') {
      $skipped++; continue
    }

    $header = Build-Header $style $HeaderLines $nl
    $insertAt = Find-InsertIndex $text

    $newText = $text.Insert($insertAt, $header)

    if ($PSCmdlet.ShouldProcess($full, "Insert/replace credits header")) {
      if ($Apply) {
        Write-File -path $full -text $newText -encoding $file.Encoding
        Write-Host "[ADD] $full"
      } else {
        Write-Host "[WOULD ADD] $full"
      }
      $changed++
    }
  }
  catch {
    Write-Warning "Skipped (error): $($f.FullName) -> $($_.Exception.Message)"
    $skipped++
  }
}

if ($Apply) {
  Write-Host "Inserted header into $changed file(s). Skipped $skipped file(s)." -ForegroundColor Green
} else {
  Write-Host "Dry-run complete. Would insert header into $changed file(s). Skipped $skipped file(s). Use -Apply to write." -ForegroundColor Yellow
}
# End of script