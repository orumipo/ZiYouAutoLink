' ZiYouAutoLink - one-shot helper for Photoshop's script-events master switch.
' Photoshop rewrites tw0001.dat every time it quits, so when the user's own
' Photoshop was open during installation we wait for it to close, and only then
' write the switch back on.
Option Explicit
Dim sh, base
Set sh = CreateObject("WScript.Shell")
base = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\ZiYouAutoLink")
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & base & "\ziyou-enable-ps-events.ps1"" -WaitForProcess Photoshop", 0, False
