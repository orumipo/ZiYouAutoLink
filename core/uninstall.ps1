<#
  ZiYouAutoLink - uninstaller.

  Removes both hooks and the runtime folder. Photoshop's event registrations are
  cleaned through COM (Photoshop is started minimized and closed again if it was
  not already running). Contains non-ASCII text, so it is saved UTF-8 with BOM.
#>
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

$installDir = Join-Path $env:LOCALAPPDATA 'ZiYouAutoLink'
$cfgPath    = Join-Path $installDir 'config.json'

function Say([string]$m) { Write-Host $m }
function Head([string]$m) { Write-Host ''; Write-Host "=== $m ===" }

Head 'ZiYouAutoLink 卸载程序'

$isAdmin = ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Say '需要管理员权限（要删除 Illustrator 安装目录里的启动脚本）。'
  Say '请右键 uninstall.bat -> 以管理员身份运行。'
  exit 1
}

$cfg = $null
if (Test-Path -LiteralPath $cfgPath) {
  try { $cfg = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
}

# ---------------------------------------------------------------------------
Head '1/3 清除 Photoshop 事件注册'
$psExe = $null
if ($cfg) { $psExe = $cfg.photoshopExe }

$startedByUs = $false
if (-not (Get-Process -Name 'Photoshop' -ErrorAction SilentlyContinue)) {
  if ($psExe -and (Test-Path -LiteralPath $psExe)) {
    Say '  Photoshop 当前没开，正在以最小化方式启动它以清除事件注册…'
    try { Start-Process -FilePath $psExe -WindowStyle Minimized; $startedByUs = $true } catch { }
  }
}

$app = $null
if (Get-Process -Name 'Photoshop' -ErrorAction SilentlyContinue) {
  for ($i = 0; $i -lt 90; $i++) {
    try { $app = New-Object -ComObject Photoshop.Application; break } catch { Start-Sleep -Seconds 2 }
  }
}

if ($app) {
  $js = @'
for (var i = app.notifiers.length - 1; i >= 0; i--) {
  try {
    var f = String(app.notifiers[i].eventFile).toLowerCase();
    if (f.indexOf('ziyouautolink') >= 0) { app.notifiers[i].remove(); }
  } catch (e) {}
}
app.notifiers.length;
'@
  try {
    $left = $app.DoJavaScript($js)
    Say "  已清除（Photoshop 现在还剩 $left 条事件脚本）"
  } catch {
    Say ('  清除失败: ' + $_.Exception.Message)
  }
  if ($startedByUs) {
    Say '  关闭刚才为清理而启动的 Photoshop…'
    try { $app.Quit() } catch { }
  }
} else {
  Say '  跳过（Photoshop 不可用）。脚本文件会被删除，残留的事件注册找不到文件会自动失效。'
}

# ---------------------------------------------------------------------------
Head '2/3 删除 Illustrator 启动脚本'
$aiExe = $null
if ($cfg) { $aiExe = $cfg.illustratorExe }
$removedAi = 0
if ($aiExe -and (Test-Path -LiteralPath $aiExe)) {
  $root = $aiExe
  for ($i = 0; $i -lt 8; $i++) {
    $root = Split-Path -Parent $root
    if ($root -and (Test-Path -LiteralPath (Join-Path $root 'Presets'))) { break }
  }
  if ($root) {
    $startup = Join-Path $root 'Startup Scripts'
    foreach ($f in @('hook-ai-start.jsx')) {
      $p = Join-Path $startup $f
      if (Test-Path -LiteralPath $p) { Microsoft.PowerShell.Management\Remove-Item -LiteralPath $p -Force; $removedAi++ }
    }
    # leave the folder itself alone if it holds anything else
    if ((Test-Path -LiteralPath $startup) -and -not (Get-ChildItem -LiteralPath $startup -Force | Select-Object -First 1)) {
      Microsoft.PowerShell.Management\Remove-Item -LiteralPath $startup -Force -Recurse
    }
    Say "  已删除 $removedAi 个文件（$startup）"
  } else {
    Say '  没找到 Illustrator 安装根目录，跳过。'
  }
} else {
  Say '  跳过（配置里没有 Illustrator 路径）'
}

# ---------------------------------------------------------------------------
Head '3/3 删除程序文件'
if (Test-Path -LiteralPath $installDir) {
  Microsoft.PowerShell.Management\Remove-Item -LiteralPath $installDir -Recurse -Force
  Say "  已删除: $installDir"
} else {
  Say '  目录不存在，跳过。'
}

Head '卸载完成'
Say '  字由现在完全由你自己手动管理，不再有任何自动联动。'
Say ''
