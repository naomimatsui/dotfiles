# =====================================================================
#  install.ps1  —  新しいPCで開発環境を再現するセットアップ
#
#  使い方:
#    1) git clone https://github.com/naomimatsui/dotfiles.git "$env:USERPROFILE\GitHub\dotfiles"
#    2) & "$env:USERPROFILE\GitHub\dotfiles\install.ps1"
#    3) 新しい PowerShell / Terminal を開いて  dev
#
#  方式: PATH に GitHub\dotfiles を登録し、dev.cmd 経由で dev を起動する。
#        （PowerShell Profile は Dropbox 同期で書き込めない環境があるため使わない）
# =====================================================================

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$GitHubRoot = Join-Path $env:USERPROFILE 'GitHub'
$DotRoot    = Join-Path $GitHubRoot 'dotfiles'

Write-Host "=== dotfiles install ===" -ForegroundColor Cyan

# 1) git ユーザー設定（家・会社で統一）
git config --global user.name  "naomimatsui"
git config --global user.email "naomimatsui@users.noreply.github.com"
Write-Host "  [1/3] git config 設定完了" -ForegroundColor Green

# 2) ユーザー PATH に dotfiles を登録（dev.cmd を PATH 経由で呼べるように）
$cur = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $cur) { $cur = '' }
if (($cur -split ';') -contains $DotRoot) {
    Write-Host "  [2/3] PATH に既に登録済み（スキップ）" -ForegroundColor DarkGray
} else {
    $new = ($cur.TrimEnd(';') + ';' + $DotRoot).TrimStart(';')
    [Environment]::SetEnvironmentVariable('Path', $new, 'User')
    Write-Host "  [2/3] PATH に dotfiles を登録（新しいシェルから有効）" -ForegroundColor Green
}

# 3) 主要リポジトリを clone（存在すればスキップ）
$repos = 'marinecore', 'akari', 'byou-awase', 'budget-cago'
if (-not (Test-Path $GitHubRoot)) { New-Item -ItemType Directory -Path $GitHubRoot -Force | Out-Null }
foreach ($r in $repos) {
    $dest = Join-Path $GitHubRoot $r
    if (Test-Path $dest) {
        Write-Host "        - $r は既に存在（スキップ）" -ForegroundColor DarkGray
    } else {
        Write-Host "        - clone: $r"
        git clone "https://github.com/naomimatsui/$r.git" $dest
    }
}
Write-Host "  [3/3] リポジトリ clone 完了" -ForegroundColor Green

Write-Host "`n完了しました。新しい PowerShell / Terminal を開いて  dev  と入力してください。" -ForegroundColor Cyan
