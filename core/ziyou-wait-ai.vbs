' ZiYouAutoLink - fallback for hosts without a usable quit hook.
' Waits for the given Adobe process to exit, then runs the same grace countdown.
Option Explicit
Dim sh, base
Set sh = CreateObject("WScript.Shell")
base = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\ZiYouAutoLink")
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & base & "\ziyou-grace.ps1"" -WaitForProcess Illustrator", 0, False
