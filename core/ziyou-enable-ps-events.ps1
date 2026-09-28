<#
  ZiYouAutoLink - make sure Photoshop's script-events master switch is ON.

  The switch is the "enable events to run scripts/actions" checkbox at the top of
  File > Scripts > Script Events Manager, stored as the first line of
  <Photoshop settings>\tw0001.dat ("true" / "false"). Photoshop ships with it OFF,
  and while it is off every registered event sits in the list and never runs.
  Photoshop rewrites that file on each quit, so a value written while it is still
  running is lost - install.ps1 therefore starts this script (via
  ziyou-enable-ps-events.vbs) with -WaitForProcess when the user's own Photoshop
  was open during installation, and only writes the file once it is gone.

  ASCII only on purpose.
#>
param([string]$WaitForProcess = '')

$ErrorActionPreference = 'SilentlyContinue'

if ($WaitForProcess) {
  while (Get-Process -Name $WaitForProcess) { Start-Sleep -Seconds 2 }
  Start-Sleep -Seconds 3          # let it finish flushing its preferences
}

$adb = Join-Path $env:APPDATA 'Adobe'
$hits = @()
foreach ($r in @(Get-ChildItem -LiteralPath $adb -Directory -Filter 'Adobe Photoshop*' -ErrorAction SilentlyContinue)) {
  foreach ($s in @(Get-ChildItem -LiteralPath $r.FullName -Directory -Filter '*Settings' -ErrorAction SilentlyContinue)) {
    $f = Join-Path $s.FullName 'tw0001.dat'
    if (Test-Path -LiteralPath $f) { $hits += (Get-Item -LiteralPath $f) }
  }
}
if ($hits.Count -eq 0) { exit 1 }
$path = ($hits | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

$b = [IO.File]::ReadAllBytes($path)
if ($b.Length -ge 4 -and [Text.Encoding]::ASCII.GetString($b, 0, 4) -eq 'true') { exit 0 }
if ($b.Length -lt 5) { exit 1 }
if ([Text.Encoding]::ASCII.GetString($b, 0, 5) -ne 'false') { exit 1 }

# byte-level splice: "false" (5 bytes) -> "true" (4 bytes); the rest, CRLF included, is kept
$new = New-Object byte[] ($b.Length - 1)
[Array]::Copy([Text.Encoding]::ASCII.GetBytes('true'), 0, $new, 0, 4)
[Array]::Copy($b, 5, $new, 4, $b.Length - 5)
[IO.File]::WriteAllBytes($path, $new)
exit 0
