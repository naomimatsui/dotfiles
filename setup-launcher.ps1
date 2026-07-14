# =====================================================================
#  setup-launcher.ps1  —  デスクトップに「Claude Code ランチャー」を作成
#
#  使い方（家PC・会社PCとも同じ / 一度だけ実行すればOK）:
#    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\GitHub\dotfiles\setup-launcher.ps1"
#
#  作成されるショートカット（ダブルクリックで dev.ps1 が起動）:
#    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\GitHub\dotfiles\dev.ps1"
#
#  方針: ユーザー名を固定しない（$env:USERPROFILE を使う）。
# =====================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- パス（固定名は使わず $env:USERPROFILE 基準） ---
$DotfilesPath = Join-Path $env:USERPROFILE 'GitHub\dotfiles'
$DevScript    = Join-Path $DotfilesPath 'dev.ps1'
$Desktop      = [Environment]::GetFolderPath('Desktop')   # OneDrive移行済みでも正しいデスクトップを取得
$LinkPath     = Join-Path $Desktop 'Claude Code ランチャー.lnk'

# powershell.exe の実体（環境に依存せず解決）
$PwshExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path $PwshExe)) { $PwshExe = 'powershell.exe' }

Write-Host "=== Claude Code ランチャー セットアップ ===" -ForegroundColor Cyan

# --- 前提チェック ---
if (-not (Test-Path $DevScript)) {
    Write-Host ("  dev.ps1 が見つかりません: {0}" -f $DevScript) -ForegroundColor Red
    Write-Host "  先に dotfiles を git clone してください。" -ForegroundColor Red
    return
}

# --- ショートカット作成（WScript.Shell の COM を使用） ---
$args = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $DevScript

try {
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($LinkPath)
    $sc.TargetPath       = $PwshExe
    $sc.Arguments        = $args
    $sc.WorkingDirectory = $DotfilesPath
    $sc.IconLocation     = "$PwshExe,0"
    $sc.Description       = 'Claude Code プロジェクトランチャー（dev.ps1）'
    $sc.WindowStyle       = 1          # 通常ウィンドウ
    $sc.Save()
} catch {
    Write-Host ("  ショートカットの作成に失敗しました: {0}" -f $_.Exception.Message) -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "  作成しました:" -ForegroundColor Green
Write-Host ("    {0}" -f $LinkPath) -ForegroundColor Gray
Write-Host ""
Write-Host "  ダブルクリックでランチャーが起動します。" -ForegroundColor Cyan
Write-Host "  実行内容:" -ForegroundColor DarkGray
Write-Host ("    {0} {1}" -f $PwshExe, $args) -ForegroundColor DarkGray
