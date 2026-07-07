# =====================================================================
#  install.ps1  —  新しいPCで開発環境を再現するセットアップ
#
#  使い方:
#    1) git clone https://github.com/naomimatsui/dotfiles.git "$env:USERPROFILE\GitHub\dotfiles"
#    2) & "$env:USERPROFILE\GitHub\dotfiles\install.ps1"
#    3) 新しい PowerShell を開いて  dev
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

# 2) PowerShell Profile に dev 関数を注入（重複は追加しない）
$marker = 'GitHub\dotfiles\dev.ps1'
$block  = @'

# ==== dotfiles managed ====
function dev   { & (Join-Path $env:USERPROFILE 'GitHub\dotfiles\dev.ps1') }
function gh-cd { Set-Location (Join-Path $env:USERPROFILE 'GitHub') }
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
'@

$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $PROFILE))    { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }

$already = Select-String -Path $PROFILE -SimpleMatch $marker -Quiet -ErrorAction SilentlyContinue
if ($already) {
    Write-Host "  [2/3] Profile に dev は既に存在（スキップ）" -ForegroundColor DarkGray
} else {
    Add-Content -Path $PROFILE -Value $block -Encoding UTF8
    Write-Host "  [2/3] Profile に dev を追加" -ForegroundColor Green
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

Write-Host "`n完了しました。新しい PowerShell を開いて  dev  と入力してください。" -ForegroundColor Cyan
