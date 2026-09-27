' ZiYouAutoLink - hidden launcher for the grace countdown (no console window).
' Started when an Adobe app quits: waits, re-checks, and only then closes the
' font client. Cancelled by ziyou-launch.vbs when an Adobe app starts again.
Option Explicit
Dim sh, base
Set sh = CreateObject("WScript.Shell")
base = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\ZiYouAutoLink")
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & base & "\ziyou-grace.ps1""", 0, False
