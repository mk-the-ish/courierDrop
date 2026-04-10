param(
  [string]$BackendDir = (Split-Path -Parent $PSScriptRoot)
)

Write-Host "Running DropCity heartbeat watchdog..."
Push-Location $BackendDir
node src/jobs/heartbeat_watchdog.js
Pop-Location
