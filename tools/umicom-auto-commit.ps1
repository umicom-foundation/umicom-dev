<# =================================================================================================
  Umicom Auto-Commit Watcher
  Author: Sammy Hegab (Umicom Foundation) â€” with AI co-pilot â€œSarahâ€
  Licence: MIT

  PURPOSE
  -------
  â€¢ Watch all project folders listed in projects.json under C:\dev\<slug>.
  â€¢ On file changes, debounce, then: git add -A ; git commit ; git push origin main.
  â€¢ Excludes typical build artefacts (build/out/dist/node_modules, etc).

  NOTE
  ----
  â€¢ This is optional. Use it when you want automatic commits while multitasking.
  â€¢ Commit messages are timestamped. You can still make handcrafted commits anytime.
================================================================================================= #>

param(
  [string]$ConfigFile = "C:\dev\projects.json",
  [string]$Root       = "C:\dev"
)

$projects = Get-Content $ConfigFile -Raw | ConvertFrom-Json
if (-not $projects) { throw "No projects found in $ConfigFile" }

# Debounce bucket per repo
$timers = @{}
$excluded = @('\build\','\out\','\dist\','\node_modules\','.git\')

function Start-Commit {
  param([string]$repoPath)

  Push-Location $repoPath
  # Skip if nothing changed
  $status = git status --porcelain
  if (-not $status) { Pop-Location; return }

  git add -A
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  git commit -m "chore: autosave ($ts) â€” main-only policy"
  git push origin main
  Pop-Location
}

foreach ($p in $projects) {
  $path = Join-Path $Root $p.slug
  if (-not (Test-Path $path)) { continue }

  $fsw = New-Object System.IO.FileSystemWatcher
  $fsw.Path = $path
  $fsw.IncludeSubdirectories = $true
  $fsw.EnableRaisingEvents = $true
  $action = {
    param($source, $eventArgs, $timers, $excluded, $repoPath)
    $full = $eventArgs.FullPath
    foreach ($ex in $excluded) { if ($full -like "*$ex*") { return } }

    # debounce 2s per repo
    if ($timers.ContainsKey($repoPath)) { $timers[$repoPath].Stop(); $timers[$repoPath].Dispose() }
    $t = New-Object Timers.Timer 2000
    $t.AutoReset = $false
    $t.add_Elapsed({ Start-Commit -repoPath $repoPath })
    $timers[$repoPath] = $t
    $t.Start()
  }

  Register-ObjectEvent $fsw Changed -Action { $action.Invoke($args[0], $args[1], $timers, $excluded, $path) } | Out-Null
  Register-ObjectEvent $fsw Created -Action { $action.Invoke($args[0], $args[1], $timers, $excluded, $path) } | Out-Null
  Register-ObjectEvent $fsw Deleted -Action { $action.Invoke($args[0], $args[1], $timers, $excluded, $path) } | Out-Null
  Register-ObjectEvent $fsw Renamed -Action { $action.Invoke($args[0], $args[1], $timers, $excluded, $path) } | Out-Null

  Write-Host "Watching: $path"
}

Write-Host "`nAuto-commit watcher running. Press Ctrl+C to stop."
while ($true) { Start-Sleep -Seconds 1 }
# End of umicom-auto-commit.ps1
