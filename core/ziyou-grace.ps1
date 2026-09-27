<#
  ZiYouAutoLink - close the font client once no watched Adobe app is running.

  Started by an Adobe "quit" hook (or, for hosts without a quit hook, by
  ziyou-wait-*.vbs which waits for that host to exit first).

  It lives for at most (remaining wait + grace) seconds and is cancelled by
  ziyou-launch.ps1 the moment an Adobe app starts again. Never resident.
  ASCII-only on purpose.
#>
param(
  [string]$BaseDir = '',
  [string]$WaitForProcess = '',
  [int]$GraceSeconds = 0
)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

if (-not $BaseDir) { $BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$cfgPath = Join-Path $BaseDir 'config.json'
$logDir = Join-Path $BaseDir 'logs'
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir 'ziyou-link.log'

function Write-Log {
  param([string]$m)
  Add-Content -LiteralPath $logFile -Value ('{0}  [grace]  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -Encoding ASCII
}

if (-not (Test-Path -LiteralPath $cfgPath)) { Write-Log 'ERROR config.json missing'; exit 1 }
$cfg = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json

$zyExe = $cfg.ziyouExe
$zyName = [IO.Path]::GetFileNameWithoutExtension($zyExe)
if ($GraceSeconds -le 0) { $GraceSeconds = [int]$cfg.graceSeconds }
if ($GraceSeconds -le 0) { $GraceSeconds = 600 }

$watched = @($cfg.adobeProcesses)
if (-not $watched -or $watched.Count -eq 0) { $watched = @('Photoshop', 'Illustrator') }

# a host without a quit hook hands us its own name first: wait for it to go away
if ($WaitForProcess) {
  Write-Log ('waiting for ' + $WaitForProcess + ' to exit')
  while (Get-Process -Name $WaitForProcess -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 5 }
  Write-Log ($WaitForProcess + ' exited')
}

Write-Log ('counting down ' + $GraceSeconds + 's')
Start-Sleep -Seconds $GraceSeconds

$stillOpen = @()
foreach ($n in $watched) {
  if (Get-Process -Name $n -ErrorAction SilentlyContinue) { $stillOpen += $n }
}
if ($stillOpen.Count -gt 0) {
  Write-Log ('another watched app is running (' + ($stillOpen -join ', ') + ') -> keeping the client')
  exit 0
}

if (-not (Get-Process -Name $zyName -ErrorAction SilentlyContinue)) {
  Write-Log 'client already gone'
  exit 0
}

Write-Log 'no watched app running -> closing the client'
foreach ($p in @(Get-Process -Name $zyName -ErrorAction SilentlyContinue)) {
  if ($p.MainWindowHandle -ne [IntPtr]::Zero) { try { [void]$p.CloseMainWindow() } catch { } }
}
for ($i = 0; $i -lt 20; $i++) {
  Start-Sleep -Milliseconds 250
  if (-not (Get-Process -Name $zyName -ErrorAction SilentlyContinue)) { Write-Log 'client closed'; exit 0 }
}
Write-Log 'client ignored the close request -> forcing'
Get-Process -Name $zyName -ErrorAction SilentlyContinue | Microsoft.PowerShell.Management\Stop-Process -Force
Start-Sleep -Milliseconds 500
if (Get-Process -Name $zyName -ErrorAction SilentlyContinue) { Write-Log 'ERROR client still running' }
else { Write-Log 'client force-closed' }
exit 0
