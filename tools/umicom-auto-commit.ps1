<# ===============================================================================================
 Umicom Auto-Commit Watcher (PowerShell)
 Author: Sammy Hegab (Umicom Foundation)
 Licence: MIT

 PURPOSE
 - Watch all git repos under a root folder.
 - On any change (excluding .git), debounce for N seconds, then:
     * ensure branch "main"
     * git add -A
     * git commit "chore: autosave (<timestamp>) - main-only policy"
     * git push (create upstream if missing)
 NOTES
 - Uses FileSystemWatcher + per-repo System.Timers.Timer for debouncing.
 - Press Ctrl+C to stop.
 =============================================================================================== #>

[CmdletBinding()]
param(
  [string]$Root = "C:\dev",
  [int]$CooldownSeconds = 2
)

$ErrorActionPreference = "Stop"

function Start-Commit {
  param([Parameter(Mandatory=$true)][string]$repoPath)

  Push-Location $repoPath

  # Ensure main
  $branch = (git rev-parse --abbrev-ref HEAD 2>$null)
  if (-not $branch -or $branch -eq "HEAD") {
    git checkout -B main 1>$null 2>$null
  } elseif ($branch -ne "main") {
    git checkout main 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) { git checkout -B main 1>$null 2>$null }
  }

  # Commit if there are changes
  $status = git status --porcelain
  if ($status) {
    git add -A
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    git commit -m "chore: autosave ($ts) - main-only policy" | Out-Null

    # Push (create upstream if needed)
    git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
      git push -u origin main
    } else {
      git push origin main
    }
    Write-Host ("Committed and pushed: {0}" -f $repoPath) -ForegroundColor Green
  }

  Pop-Location
}

# Per-repo debounce timers
$timers = @{}

function Arm-Timer {
  param([string]$repoPath, [int]$ms)

  if ($timers.ContainsKey($repoPath)) {
    try { $timers[$repoPath].Stop(); $timers[$repoPath].Dispose() } catch {}
    $timers.Remove($repoPath) | Out-Null
  }

  $t = New-Object System.Timers.Timer
  $t.Interval = $ms
  $t.AutoReset = $false
  Register-ObjectEvent -InputObject $t -EventName Elapsed -MessageData $repoPath -Action {
    Start-Commit -repoPath $Event.MessageData
  } | Out-Null
  $t.Start()
  $timers[$repoPath] = $t
}

function Watch-Repo {
  param([string]$path)

  $fsw = New-Object System.IO.FileSystemWatcher $path -Property @{
    Filter = '*'; IncludeSubdirectories = $true; EnableRaisingEvents = $true
  }

  $action = {
    param($src, $e)
    # Ignore changes inside .git
    if ($e.FullPath -match '\\\.git(\\|$)') { return }
    Arm-Timer -repoPath $using:path -ms ($using:CooldownSeconds * 1000)
  }

  Register-ObjectEvent $fsw Changed -Action $action | Out-Null
  Register-ObjectEvent $fsw Created -Action $action | Out-Null
  Register-ObjectEvent $fsw Deleted -Action $action | Out-Null
  Register-ObjectEvent $fsw Renamed -Action $action | Out-Null

  Write-Host "Watching: $path"
}

# Discover repos
$repos = Get-ChildItem -Path $Root -Directory | Where-Object { Test-Path (Join-Path $_.FullName ".git") }
foreach ($r in $repos) { Watch-Repo -path $r.FullName }

Write-Host "`nAuto-commit watcher running. Press Ctrl+C to stop."
try {
  while ($true) { Start-Sleep -Seconds 1 }
} finally {
  # Cleanup timers + event subscribers
  foreach ($t in $timers.Values) { try { $t.Stop(); $t.Dispose() } catch {} }
  Get-EventSubscriber | Where-Object {
    $_.SourceObject -is [System.IO.FileSystemWatcher] -or $_.SourceObject -is [System.Timers.Timer]
  } | Unregister-Event -Force
}
Write-Host "Watcher stopped."
