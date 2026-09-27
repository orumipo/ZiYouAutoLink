<#
  ZiYouAutoLink - launch the font client alongside an Adobe app.

  Runs once per Adobe "start" event and exits immediately. It is never resident:
  the only thing it leaves behind (for ~15s) is the window-pressing loop below.
  ASCII-only on purpose so it survives any ANSI code page on the host.
#>
param(
  [string]$BaseDir = ''
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
  Add-Content -LiteralPath $logFile -Value ('{0}  [launch] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -Encoding ASCII
}

if (-not (Test-Path -LiteralPath $cfgPath)) { Write-Log 'ERROR config.json missing'; exit 1 }
$cfg = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json

$zyExe = $cfg.ziyouExe
$zyDir = $cfg.ziyouDir
$zyName = [IO.Path]::GetFileNameWithoutExtension($zyExe)

# ---------------------------------------------------------------------------
# an Adobe app just started -> any pending "close the client" countdown is void
# ---------------------------------------------------------------------------
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -like '*ziyou-grace.ps1*' } |
  ForEach-Object { Microsoft.PowerShell.Management\Stop-Process -Id $_.ProcessId -Force }

if (Get-Process -Name $zyName -ErrorAction SilentlyContinue) {
  Write-Log 'client already running, nothing to do'
  exit 0
}
if (-not (Test-Path -LiteralPath $zyExe)) { Write-Log ('ERROR client exe not found: ' + $zyExe); exit 1 }

# ---------------------------------------------------------------------------
# window helpers (optional - without them the client still starts, just not minimized)
# ---------------------------------------------------------------------------
$noWin32 = $false
try {
  if (-not ('ZiYouLink.User32' -as [type])) {
    Add-Type -Namespace ZiYouLink -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
'@
  }
} catch {
  $noWin32 = $true
  Write-Log ('WARN user32 helpers unavailable: ' + $_.Exception.Message)
}

function Restore-Foreground {
  param([IntPtr]$Target, [IntPtr]$Stolen)
  if ($Target -eq [IntPtr]::Zero) { return }
  if ($Stolen -ne [IntPtr]::Zero -and $Stolen -eq $Target) { return }
  if ([ZiYouLink.User32]::SetForegroundWindow($Target)) { return }
  $pTarget = [uint32]0
  $pStolen = [uint32]0
  $tTarget = [ZiYouLink.User32]::GetWindowThreadProcessId($Target, [ref]$pTarget)
  $tStolen = [ZiYouLink.User32]::GetWindowThreadProcessId($Stolen, [ref]$pStolen)
  $tMe = [ZiYouLink.User32]::GetCurrentThreadId()
  [void][ZiYouLink.User32]::AttachThreadInput($tMe, $tStolen, $true)
  [void][ZiYouLink.User32]::AttachThreadInput($tMe, $tTarget, $true)
  [void][ZiYouLink.User32]::SetForegroundWindow($Target)
  [void][ZiYouLink.User32]::AttachThreadInput($tMe, $tTarget, $false)
  [void][ZiYouLink.User32]::AttachThreadInput($tMe, $tStolen, $false)
}

# ---------------------------------------------------------------------------
# start the client and out-hustle it: it shows itself and steals the foreground
# for a few seconds, so keep pressing it down and hand the focus back
# ---------------------------------------------------------------------------
$prevFg = [IntPtr]::Zero
if (-not $noWin32) { $prevFg = [ZiYouLink.User32]::GetForegroundWindow() }

Write-Log 'Adobe start detected -> launching the font client'
try {
  $p = Start-Process -FilePath $zyExe -WorkingDirectory $zyDir -PassThru
} catch {
  Write-Log ('ERROR Start-Process failed: ' + $_.Exception.Message)
  exit 1
}
if (-not $p) { Write-Log 'ERROR Start-Process returned nothing'; exit 1 }

$deadline = (Get-Date).AddSeconds(15)
$sawWindow = $false
$minimizeCalls = 0
$pushBacks = 0
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 120
  $proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
  if (-not $proc) { break }                 # handed over to an already running instance
  $proc.Refresh()
  $h = $proc.MainWindowHandle
  if ($h -eq [IntPtr]::Zero) { continue }
  $sawWindow = $true
  if ($noWin32) { continue }
  if (-not [ZiYouLink.User32]::IsIconic($h)) {
    [void][ZiYouLink.User32]::ShowWindow($h, 6)           # SW_MINIMIZE
    $minimizeCalls++
  }
  $fg = [ZiYouLink.User32]::GetForegroundWindow()
  if ($fg -ne [IntPtr]::Zero -and $fg -ne $prevFg) {
    $fgPid = [uint32]0
    [void][ZiYouLink.User32]::GetWindowThreadProcessId($fg, [ref]$fgPid)
    if ($fgPid -eq [uint32]$p.Id) {
      Restore-Foreground -Target $prevFg -Stolen $fg
      $pushBacks++
    }
  }
}

if ($sawWindow) { Write-Log ('client settled; minimize calls=' + $minimizeCalls + ' foreground restored=' + $pushBacks) }
else { Write-Log 'WARN no client window observed during launch' }
exit 0
