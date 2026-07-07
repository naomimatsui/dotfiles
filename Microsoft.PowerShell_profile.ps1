# =====================================================================
#  PowerShell Profile  (dotfiles 管理マスター)
#  実体の $PROFILE から dot-source される、または install.ps1 で反映される
# =====================================================================

# どのPC・どのユーザー名でも動くよう $env:USERPROFILE を使用
function dev {
    & (Join-Path $env:USERPROFILE 'GitHub\dotfiles\dev.ps1')
}

# GitHub フォルダへ素早く移動
function gh-cd {
    Set-Location (Join-Path $env:USERPROFILE 'GitHub')
}

# 日本語表示のため
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
