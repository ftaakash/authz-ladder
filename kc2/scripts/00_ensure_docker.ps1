# Pilot 08 — OPERATOR PREFLIGHT ONLY (user-authorised 2026-10-29: "you start it automatically").
# Ensures the Docker engine is up before a test step. If it is not answering, it launches Docker Desktop as a
# DETACHED process (Start-Process, no inherited console/process tree) and waits until `docker info` succeeds.
#
# NEVER call this from inside a test script (scripts/lib.sh require_docker stays check-only): launching
# Docker Desktop from within a test script's own process tree is what hung a KC1 batch (review 9, N1).
#
# Why it was needed (diagnosed 2026-10-29): Docker Desktop's own setting AutoStart=false, and every recorded
# stop is "backend process exited: exit status 0x40010004" (DBG_TERMINATE_PROCESS — terminated from outside,
# not a crash), roughly daily since 2026-10-16.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File kc2/scripts/00_ensure_docker.ps1 [-TimeoutSec 180]
param([int]$TimeoutSec = 180)
$ErrorActionPreference = 'SilentlyContinue'
function Test-Engine { docker info --format '{{.ServerVersion}}' 2>$null | Out-Null; return ($LASTEXITCODE -eq 0) }
if (Test-Engine) { Write-Output "docker engine already up"; exit 0 }
$exe = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe'
if (-not (Test-Path $exe)) { $exe = 'C:\Program Files\Docker\Docker\Docker Desktop.exe' }
if (-not (Test-Path $exe)) { Write-Output "Docker Desktop executable not found"; exit 2 }
Write-Output "docker engine down - starting Docker Desktop (detached): $exe"
Start-Process -FilePath $exe | Out-Null
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
  if (Test-Engine) { Write-Output "docker engine up after start"; exit 0 }
  Start-Sleep -Seconds 3
}
Write-Output "docker engine did not come up within $TimeoutSec s"; exit 1
