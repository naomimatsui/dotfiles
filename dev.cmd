@echo off
rem dev.cmd - launch the Claude Code project launcher from any shell
rem -NoProfile avoids loading the (Dropbox-synced) PowerShell profile
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dev.ps1"
