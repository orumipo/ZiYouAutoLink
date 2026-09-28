<#
  ZiYouAutoLink - installer.

  What this does (all zero-resident):
    1. locates the font client (registry uninstall entry / shortcuts / common paths)
    2. locates Photoshop and Illustrator
    3. copies the runtime pieces into %LOCALAPPDATA%\ZiYouAutoLink
    4. registers two Photoshop script events (Start Application / Quit Application)
       through Photoshop's COM automation - the same thing the Script Events
       Manager does, just done for the user
    5. creates a Startup Scripts\ folder inside the Illustrator install directory
       and drops the startup hook there (per Adobe's Illustrator Scripting Guide)

  Nothing is left running. Adobe apps call into us on start/quit; we do our work
  and exit.

  This file contains non-ASCII text, so it is saved as UTF-8 with BOM - Windows
  PowerShell decodes scripts with the ANSI code page otherwise.
#>
param(
  [switch]$AllowNoAdmin    # debug switch: skip the elevation check (the Illustrator part will fail)
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

$installDir   = Join-Path $env:LOCALAPPDATA 'ZiYouAutoLink'
$coreDir      = $PSScriptRoot    # install.ps1 lives next to the runtime pieces
$graceSeconds = 600

function Say([string]$m) { Write-Host $m }
function Head([string]$m) { Write-Host ''; Write-Host "=== $m ===" }

# ---------------------------------------------------------------------------
Head 'ZiYouAutoLink 安装程序'

$isAdmin = ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $AllowNoAdmin) {
  Say '需要管理员权限（要往 Illustrator 安装目录写入启动脚本）。'
  Say '请右键 install.bat -> 以管理员身份运行。'
  exit 1
}

# ---------------------------------------------------------------------------
Head '1/6 查找字由'
function Find-ZiYouExe {
  $found = New-Object System.Collections.Generic.List[string]

  $keys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  foreach ($k in $keys) {
    $items = Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match '字由|HelloFont|ZiYou' }
    foreach ($it in @($items)) {
      if ($it.DisplayIcon) {
        $p = ($it.DisplayIcon -split ',')[0].Trim().Trim('"')
        if ($p -and (Test-Path -LiteralPath $p)) { $found.Add($p) }
      }
      if ($it.InstallLocation) {
        $p2 = Join-Path $it.InstallLocation '字由.exe'
        if (Test-Path -LiteralPath $p2) { $found.Add($p2) }
      }
    }
  }

  $lnkRoots = @(
    (Join-Path $env:USERPROFILE 'Desktop'),
    (Join-Path $env:PUBLIC 'Desktop'),
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs')
  )
  try {
    $wsh = New-Object -ComObject WScript.Shell
    foreach ($r in $lnkRoots) {
      if (-not (Test-Path -LiteralPath $r)) { continue }
      Get-ChildItem -LiteralPath $r -Recurse -Filter *.lnk -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '字由|HelloFont|ZiYou' } |
        ForEach-Object {
          $t = $wsh.CreateShortcut($_.FullName).TargetPath
          if ($t -and (Test-Path -LiteralPath $t)) { $found.Add($t) }
        }
    }
  } catch { }

  foreach ($d in @('D:\SUPER TOOLS\hellofont', 'C:\Program Files\hellofont', 'D:\hellofont', 'C:\hellofont')) {
    $p = Join-Path $d '字由.exe'
    if (Test-Path -LiteralPath $p) { $found.Add($p) }
  }

  $seen = @{}
  foreach ($c in $found) {
    if ($seen.ContainsKey($c)) { continue }
    $seen[$c] = $true
    return $c
  }
  return $null
}

$zyExe = Find-ZiYouExe
if (-not $zyExe) {
  Say '没有找到字由客户端。'
  Say '请先安装字由，或手动把 字由.exe 的完整路径写在下面。'
  $manual = Read-Host '字由.exe 路径（直接回车放弃）'
  if ($manual -and (Test-Path -LiteralPath $manual.Trim('"'))) { $zyExe = $manual.Trim('"') }
  else { Say '已取消。'; exit 1 }
}
Say "  字由: $zyExe"
$zyName = [IO.Path]::GetFileNameWithoutExtension($zyExe)

# ---------------------------------------------------------------------------
Head '2/6 查找 Adobe 应用'
function Find-AppExe([string]$exeName, [string[]]$extraRoots) {
  foreach ($root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths',
                      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths')) {
    $k = Join-Path $root $exeName
    if (Test-Path $k) {
      $v = (Get-ItemProperty $k -ErrorAction SilentlyContinue).'(default)'
      if ($v -and (Test-Path -LiteralPath $v)) { return $v }
    }
  }
  $roots = @()
  if ($env:ProgramFiles) { $roots += (Join-Path $env:ProgramFiles 'Adobe') }
  if (${env:ProgramFiles(x86)}) { $roots += (Join-Path ${env:ProgramFiles(x86)} 'Adobe') }
  $roots += $extraRoots
  foreach ($r in $roots) {
    if (-not $r -or -not (Test-Path -LiteralPath $r)) { continue }
    $hit = Get-ChildItem -LiteralPath $r -Recurse -Depth 5 -Filter $exeName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
  }
  return $null
}

$searchRoots = @()
foreach ($d in @('D:\', 'E:\', 'F:\', 'C:\')) {
  if (Test-Path $d) { $searchRoots += $d }
}
$psExe = Find-AppExe 'Photoshop.exe' @('D:\ADOBESW', 'D:\Adobe', 'E:\ADOBESW', 'G:\ADOBESW')
$aiExe = Find-AppExe 'Illustrator.exe' @('D:\ADOBESW', 'D:\AI', 'D:\Adobe', 'E:\ADOBESW')
if ($psExe) { Say "  Photoshop: $psExe" } else { Say '  Photoshop: 未找到（将跳过 PS 注册）' }
if ($aiExe) { Say "  Illustrator: $aiExe" } else { Say '  Illustrator: 未找到（将跳过 AI 启动脚本）' }

# ---------------------------------------------------------------------------
Head '3/6 部署文件'
if (-not (Test-Path -LiteralPath $coreDir)) { Say "找不到 core 目录: $coreDir"; exit 1 }
if (Get-Process -Name $zyName -ErrorAction SilentlyContinue) { } # client may be running, harmless
if (-not (Test-Path -LiteralPath $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
Copy-Item -Path (Join-Path $coreDir '*') -Destination $installDir -Force -Recurse
Say "  已部署到: $installDir"

$config = [ordered]@{
  version        = 1
  installedAt    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  ziyouExe       = $zyExe
  ziyouDir       = (Split-Path -Parent $zyExe)
  graceSeconds   = $graceSeconds
  adobeProcesses = @('Photoshop', 'Illustrator')
  photoshopExe   = $psExe
  illustratorExe = $aiExe
}
$configPath = Join-Path $installDir 'config.json'
[IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
Say "  已写入配置: $configPath"

# ---------------------------------------------------------------------------
Head '4/6 注册 Photoshop 事件'
$psResult = 'skipped'
if ($psExe) {
  $startJsx = Join-Path $installDir 'hook-ps-start.jsx'
  $quitJsx  = Join-Path $installDir 'hook-ps-quit.jsx'

  $startedByUs = $false
  if (-not (Get-Process -Name 'Photoshop' -ErrorAction SilentlyContinue)) {
    Say '  Photoshop 当前没开，正在以最小化方式启动它以完成注册…'
    try { Start-Process -FilePath $psExe -WindowStyle Minimized; $startedByUs = $true } catch { }
  } else {
    Say '  Photoshop 正在运行，直接注册（不会打断你手头的文件）。'
  }

  $app = $null
  for ($i = 0; $i -lt 90; $i++) {
    try { $app = New-Object -ComObject Photoshop.Application; break } catch { Start-Sleep -Seconds 2 }
  }

  if ($app) {
    $s = $startJsx.Replace('\', '/')
    $q = $quitJsx.Replace('\', '/')
    # NOTE: the Notifiers collection has no remove() method - each notifier node
    # removes itself. Only entries pointing into our own install directory are
    # touched, so any notifier the user registered by hand is left alone.
    $js = @"
for (var i = app.notifiers.length - 1; i >= 0; i--) {
  try {
    var f = String(app.notifiers[i].eventFile).toLowerCase();
    if (f.indexOf('ziyouautolink') >= 0) { app.notifiers[i].remove(); }
  } catch (e) {}
}
app.notifiers.add('Start Application', new File('$s'));
app.notifiers.add('Quit Application', new File('$q'));
app.notifiers.length;
"@
    try {
      $len = $app.DoJavaScript($js)
      Say "  已注册（当前 Photoshop 共有 $len 条事件脚本）"
      $psResult = 'ok'
    } catch {
      Say ('  注册失败: ' + $_.Exception.Message)
      $psResult = 'failed'
    }
    if ($startedByUs) {
      Say '  关闭刚才为注册而启动的 Photoshop…'
      try { $app.Quit() } catch { }
      # Preferences (and with them the script-events switch) are only flushed on
      # exit, so wait for the process to really go away before touching the file.
      for ($i = 0; $i -lt 60; $i++) {
        if (-not (Get-Process -Name 'Photoshop' -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Seconds 1
      }
      Start-Sleep -Seconds 2
      Say '  已退出。'
    }
  } else {
    Say '  连接 Photoshop 失败（COM 不可用）。PS 侧未注册。'
    $psResult = 'com-failed'
  }
} else {
  Say '  跳过（没找到 Photoshop）'
}

# ---------------------------------------------------------------------------
Head '5/6 打开 Photoshop 的脚本事件总开关'
# Photoshop gates *all* script events behind one master switch - the
# "启用事件以运行脚本/动作" checkbox at the top of 文件 > 脚本 > 脚本事件管理器.
# It ships OFF, and while it is off a registered event sits in the list and is
# never run (the registration looks fine, nothing happens). The switch is the
# first line of <Photoshop settings>\tw0001.dat ("true"/"false").
# The catch: Photoshop rewrites that file every time it quits, so a flip made
# while it is running gets lost. We therefore only write the file once the
# instance we started has exited; if the user's own Photoshop is still open we
# leave a one-shot helper that waits for it to close and flips it again.
$eventsResult = 'skipped'

function Find-PsEventsFile {
  $adb = Join-Path $env:APPDATA 'Adobe'
  if (-not (Test-Path -LiteralPath $adb)) { return $null }
  $hits = @()
  foreach ($r in @(Get-ChildItem -LiteralPath $adb -Directory -Filter 'Adobe Photoshop*' -ErrorAction SilentlyContinue)) {
    foreach ($s in @(Get-ChildItem -LiteralPath $r.FullName -Directory -Filter '*Settings' -ErrorAction SilentlyContinue)) {
      $f = Join-Path $s.FullName 'tw0001.dat'
      if (Test-Path -LiteralPath $f) { $hits += (Get-Item -LiteralPath $f) }
    }
  }
  if ($hits.Count -eq 0) { return $null }
  # the file for the Photoshop we just registered with is the freshest one
  return ($hits | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function Enable-PsScriptEvents {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return 'no-file' }
  $b = [IO.File]::ReadAllBytes($Path)
  if ($b.Length -lt 5) { return 'short' }
  if ([Text.Encoding]::ASCII.GetString($b, 0, 4) -eq 'true') { return 'already-on' }
  if ([Text.Encoding]::ASCII.GetString($b, 0, 5) -ne 'false') { return 'unexpected' }
  # byte-level splice: "false" (5) -> "true" (4); the rest, CRLF included, is kept
  $new = New-Object byte[] ($b.Length - 1)
  [Array]::Copy([Text.Encoding]::ASCII.GetBytes('true'), 0, $new, 0, 4)
  [Array]::Copy($b, 5, $new, 4, $b.Length - 5)
  [IO.File]::WriteAllBytes($Path, $new)
  return 'flipped'
}

if ($psResult -eq 'ok') {
  $eventsFile = Find-PsEventsFile
  if (-not $eventsFile) {
    Say '  找不到 Photoshop 的脚本事件设置文件（tw0001.dat），跳过。'
    $eventsResult = 'no-file'
  } else {
    Say "  设置文件: $eventsFile"
    if ($startedByUs) {
      $eventsResult = Enable-PsScriptEvents -Path $eventsFile
    } else {
      # their Photoshop is open; whatever we write now is overwritten on quit
      Enable-PsScriptEvents -Path $eventsFile | Out-Null
      $eventsResult = 'deferred'
      try {
        Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\wscript.exe') `
          -ArgumentList "`"$installDir\ziyou-enable-ps-events.vbs`"" -WindowStyle Hidden | Out-Null
        Say '  Photoshop 正开着，已留一个一次性助手：等它关闭后再把开关写回去。'
      } catch {
        Say ('  提示：请在关闭 Photoshop 后再运行一次 install.bat。（' + $_.Exception.Message + '）')
      }
    }
    switch ($eventsResult) {
      'flipped'    { Say '  已打开脚本事件总开关 ✓' }
      'already-on' { Say '  脚本事件总开关本来就是打开的 ✓' }
      'deferred'   { Say '  开关已写入，等待 Photoshop 退出后由助手再次确认 ✓' }
      default      { Say "  未能确认开关状态（$eventsResult）" }
    }
  }
} else {
  Say '  跳过（PS 侧未注册成功）'
}

# ---------------------------------------------------------------------------
Head '6/6 安装 Illustrator 启动脚本'
$aiResult = 'skipped'
if ($aiExe) {
  # Per Adobe's Illustrator Scripting Guide, application-specific startup scripts
  # live in a "Startup Scripts" folder inside the Illustrator install directory -
  # NOT under Presets. The install directory is the one holding Presets/, which is
  # one level above the "Support Files\Contents\Windows" folder with the exe.
  try {
    $root = $aiExe
    for ($i = 0; $i -lt 8; $i++) {
      $root = Split-Path -Parent $root
      if ($root -and (Test-Path -LiteralPath (Join-Path $root 'Presets'))) { break }
    }
    if ($root -and (Test-Path -LiteralPath (Join-Path $root 'Presets'))) {
      $startup = Join-Path $root 'Startup Scripts'
      if (-not (Test-Path -LiteralPath $startup)) { New-Item -ItemType Directory -Path $startup -Force | Out-Null }
      Copy-Item -LiteralPath (Join-Path $installDir 'hook-ai-start.jsx') -Destination $startup -Force
      Say "  已放入: $startup"
      $aiResult = 'ok'
    } else {
      Say '  没找到 Illustrator 的安装根目录（含 Presets 的那一层），跳过。'
      $aiResult = 'no-root'
    }
  } catch {
    Say ('  写入失败（通常是没有管理员权限）: ' + $_.Exception.Message)
    $aiResult = 'failed'
  }
} else {
  Say '  跳过（没找到 Illustrator）'
}

# ---------------------------------------------------------------------------
Head '安装结果'
Say "  字由          : $zyExe"
Say "  宽限期        : $graceSeconds 秒（Adobe 全部退出后开始计时）"
switch ($psResult) {
  'ok'         { Say '  Photoshop     : 已注册启动/退出事件 ✓' }
  'failed'     { Say '  Photoshop     : 注册失败 ✗（见上面的错误）' }
  'com-failed' { Say '  Photoshop     : 无法连接 COM ✗' }
  default      { Say '  Photoshop     : 已跳过' }
}
switch ($aiResult) {
  'ok'      { Say '  Illustrator   : 已安装启动脚本 ✓' }
  'no-root' { Say '  Illustrator   : 没找到安装根目录 ✗' }
  default   { Say '  Illustrator   : 已跳过' }
}
Say ''
Say '  结论：'
if ($psResult -eq 'ok' -or $aiResult -eq 'ok') {
  Say '   · 打开 Photoshop / Illustrator 时，字由会自动在后台起来（最小化，不抢焦点）'
  Say '   · 全部退出 %GRACE% 秒内没有再打开，字由会被自动关掉'.Replace('%GRACE%', $graceSeconds)
  Say '   · 机器上没有任何常驻进程，只在 Adobe 启停那一刻短暂动作'
  Say ''
  Say "  日志: $installDir\logs\ziyou-link.log"
} else {
  Say '    两个都失败了，请把上面的信息发给开发者。'
}
Say ''
Say '  卸载：运行 uninstall.bat'
Say ''
