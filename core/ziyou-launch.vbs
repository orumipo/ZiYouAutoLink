' ZiYouAutoLink - hidden launcher for the font client (no console window).
' No path is hardcoded: %LOCALAPPDATA% is expanded at run time, which keeps this
' file pure ASCII and safe under any ANSI code page (paths with non-ASCII
' characters still resolve correctly).
Option Explicit
Dim sh, base
Set sh = CreateObject("WScript.Shell")
base = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\ZiYouAutoLink")
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & base & "\ziyou-launch.ps1""", 0, False
