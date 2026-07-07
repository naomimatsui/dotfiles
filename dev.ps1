# =====================================================================
#  dev.ps1  —  Claude Code プロジェクトランチャー  (dev 2.0)
#  使い方: PowerShell で  dev  と入力
#
#  方針:
#   - Obsidian Vault は「普段使いの中心」。git操作は一切しない（Google Drive同期）。
#   - GitHubプロジェクトを選んだ日だけ、開始時pull・終了時push（どちらも確認付き）。
#   - 固定パス(adoni等)は使わない。GitHubルート=$env:USERPROFILE\GitHub。
#   - Claude起動は Store版 / 通常版 / PATH の3段フォールバック（家PC・会社PC対応）。
# =====================================================================

# 日本語表示のため入出力を UTF-8 に
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root      = Join-Path $env:USERPROFILE 'GitHub'
$VaultPath = 'G:\マイドライブ\Obsidian Vault'
$HomeAiPath = Join-Path $VaultPath 'App Ideas\HomeAI Project'

# フォルダ名 -> 表示名（自動追加リポ用。増えたらここに追記）
$DisplayNames = @{
    'marinecore'  = 'MARINE CORE'
    'akari'       = 'AKARI'
    'byou-awase'  = '秒合わせ'
    'budget-cago' = '予算カゴ'
    'butudan-app' = '仏壇アプリ'
}
function Get-Disp($name) {
    if ($DisplayNames.ContainsKey($name)) { return $DisplayNames[$name] }
    return $name
}

# --- claude.exe を動的に解決（PATH → Store版 → 通常版） ---
function Resolve-ClaudeExe {
    # ① PATH上の claude（npm版・シム等）
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) { return $cmd.Source }

    # ② Windows Store版: LocalAppData\Packages\Claude_*\LocalCache\Roaming\Claude\claude-code
    $storePackage = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($storePackage) {
        $dir = Join-Path $storePackage.FullName 'LocalCache\Roaming\Claude\claude-code'
        if (Test-Path $dir) {
            $v = Get-ChildItem $dir -Directory -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
            if ($v) { $exe = Join-Path $v.FullName 'claude.exe'; if (Test-Path $exe) { return $exe } }
        }
    }

    # ③ 通常版: %APPDATA%\Claude\claude-code
    $dir = Join-Path $env:APPDATA 'Claude\claude-code'
    if (Test-Path $dir) {
        $v = Get-ChildItem $dir -Directory -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
        if ($v) { $exe = Join-Path $v.FullName 'claude.exe'; if (Test-Path $exe) { return $exe } }
    }
    return $null
}

function Start-Claude {
    $exe = Resolve-ClaudeExe
    if (-not $exe) {
        Write-Host "   claude が見つかりません（Store版/通常版/PATHいずれも）。" -ForegroundColor Red
        Write-Host "   Claude Desktop のインストール、または 'claude' が PATH にあるか確認してください。" -ForegroundColor Red
        return $false
    }
    Write-Host "   Claude Code を起動します..." -ForegroundColor Cyan
    Write-Host ""
    & $exe            # claude 終了までブロック
    return $true
}

# --- あれば表示するドキュメント ---
function Show-Docs($path) {
    foreach ($f in @('README.md', 'TODO.md', 'CHANGELOG.md')) {
        $p = Join-Path $path $f
        if (Test-Path $p) {
            Write-Host ""
            Write-Host ("----- {0} -----" -f $f) -ForegroundColor Magenta
            Get-Content -Path $p -Encoding UTF8 | ForEach-Object { Write-Host "   $_" }
        }
    }
}

# =====================================================================
#  メニュー構築：Obsidian Vault を先頭に、既知プロジェクトを希望順、
#  未知の GitHub リポは末尾に自動追加。
# =====================================================================
$layout = @(
    [ordered]@{ Kind = 'obsidian'; Disp = 'Obsidian Vault'; Path = $VaultPath }
    [ordered]@{ Kind = 'git';      Disp = 'AKARI';          Folder = 'akari' }
    [ordered]@{ Kind = 'nogit';    Disp = 'HomeAI';         Path = $HomeAiPath }
    [ordered]@{ Kind = 'git';      Disp = '秒合わせ';        Folder = 'byou-awase' }
    [ordered]@{ Kind = 'git';      Disp = '予算カゴ';        Folder = 'budget-cago' }
    [ordered]@{ Kind = 'git';      Disp = 'MARINE CORE';     Folder = 'marinecore' }
)

$menu = @()
foreach ($e in $layout) {
    if ($e.Kind -eq 'git') {
        $path = Join-Path $Root $e.Folder
        $menu += [pscustomobject]@{ Disp = $e.Disp; Path = $path; Kind = 'git'; Exists = (Test-Path (Join-Path $path '.git')) }
    } else {
        $menu += [pscustomobject]@{ Disp = $e.Disp; Path = $e.Path; Kind = $e.Kind; Exists = (Test-Path $e.Path) }
    }
}

# 既知以外の GitHub リポを自動追加（dotfiles は開発対象外なので除外）
$knownFolders = @('akari', 'byou-awase', 'budget-cago', 'marinecore')
$extra = Get-ChildItem -Path $Root -Directory -ErrorAction SilentlyContinue |
    Where-Object { (Test-Path (Join-Path $_.FullName '.git')) -and $_.Name -ne 'dotfiles' -and ($knownFolders -notcontains $_.Name) } |
    Sort-Object Name
foreach ($x in $extra) {
    $menu += [pscustomobject]@{ Disp = (Get-Disp $x.Name); Path = $x.FullName; Kind = 'git'; Exists = $true }
}

# ---- 一覧表示 ----
Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "   Claude Code  プロジェクト選択" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""
for ($i = 0; $i -lt $menu.Count; $i++) {
    $m = $menu[$i]
    $tag = ''
    if     ($m.Kind -eq 'obsidian') { $tag = '  [Obsidian / git無]' }
    elseif ($m.Kind -eq 'nogit')    { $tag = '  [企画 / git無]' }
    if (-not $m.Exists) {
        if ($m.Kind -eq 'git') { $tag = '  [リポジトリ未作成]' } else { $tag = '  [見つかりません]' }
    }
    Write-Host ("   {0})  {1}{2}" -f ($i + 1), $m.Disp, $tag)
}
Write-Host ""

$sel = Read-Host "   番号を入力 (q=中止)"
if ($sel -eq 'q' -or [string]::IsNullOrWhiteSpace($sel)) { return }
$idx = ($sel -as [int]) - 1
if ($null -eq ($sel -as [int]) -or $idx -lt 0 -or $idx -ge $menu.Count) {
    Write-Host "   無効な番号です。" -ForegroundColor Red
    return
}
$proj = $menu[$idx]

# =====================================================================
#  分岐A：Obsidian Vault（git操作なし）
# =====================================================================
if ($proj.Kind -eq 'obsidian') {
    if (-not (Test-Path $proj.Path)) {
        Write-Host ""
        Write-Host ("   Obsidian Vault が見つかりません: {0}" -f $proj.Path) -ForegroundColor Red
        Write-Host "   Google Drive がマウントされているか確認してください。" -ForegroundColor Red
        return
    }
    Set-Location $proj.Path
    Write-Host ""
    Write-Host "===================================" -ForegroundColor Green
    Write-Host "   Obsidian Vault   重要ファイル確認" -ForegroundColor Green
    Write-Host "===================================" -ForegroundColor Green
    foreach ($f in @('🏠 HOME.md', 'PROJECTS.md', 'TODAY.md', '_system\INDEX.md')) {
        $ok = Test-Path (Join-Path $proj.Path $f)
        $mark = if ($ok) { '✓' } else { '✗' }
        $col  = if ($ok) { 'Gray' } else { 'Yellow' }
        Write-Host ("   {0}  {1}" -f $mark, $f) -ForegroundColor $col
    }
    Write-Host ""
    Write-Host "   ※ Obsidian Vault は git操作なし（Google Drive同期に任せる）" -ForegroundColor DarkGray
    Write-Host ""
    [void](Start-Claude)
    # 終了後も git 操作はしない
    return
}

# =====================================================================
#  分岐 HomeAI：企画フォルダを開くだけ（git操作なし）
# =====================================================================
if ($proj.Kind -eq 'nogit') {
    if (-not (Test-Path $proj.Path)) {
        Write-Host ""
        Write-Host ("   企画フォルダが見つかりません: {0}" -f $proj.Path) -ForegroundColor Red
        return
    }
    Set-Location $proj.Path
    Write-Host ""
    Write-Host ("   {0}：企画フォルダを開きます（GitHubリポは未作成 / git操作なし）" -f $proj.Disp) -ForegroundColor Green
    Write-Host ("   場所: {0}" -f $proj.Path) -ForegroundColor DarkGray
    Show-Docs $proj.Path
    Write-Host ""
    [void](Start-Claude)
    return
}

# =====================================================================
#  分岐B：GitHubプロジェクト
# =====================================================================
if (-not $proj.Exists) {
    Write-Host ""
    Write-Host ("   {0} のリポジトリがまだありません: {1}" -f $proj.Disp, $proj.Path) -ForegroundColor Yellow
    Write-Host "   先に git clone / init してから使ってください。" -ForegroundColor Yellow
    return
}
Set-Location $proj.Path

# ---- git status ----
Write-Host ""
Write-Host "===================================" -ForegroundColor Green
Write-Host ("   {0}   git status" -f $proj.Disp) -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
git fetch --quiet 2>$null
$branch = (git rev-parse --abbrev-ref HEAD 2>$null)
$dirty  = git status --porcelain
$ahead  = (git rev-list --count '@{u}..HEAD' 2>$null)
$behind = (git rev-list --count 'HEAD..@{u}' 2>$null)
if (-not $ahead)  { $ahead = 0 }
if (-not $behind) { $behind = 0 }

Write-Host ("   Branch     : {0}" -f $branch)
if ([string]::IsNullOrWhiteSpace($dirty)) {
    Write-Host "   未コミット : なし (clean)"
} else {
    $n = ($dirty -split "`r?`n" | Where-Object { $_ }).Count
    Write-Host ("   未コミット : {0} 件の変更あり" -f $n) -ForegroundColor Yellow
}
Write-Host ("   未Push     : {0} commit(s) ahead" -f $ahead) -ForegroundColor $(if ([int]$ahead -gt 0) { 'Yellow' } else { 'Gray' })
if ([int]$behind -gt 0) {
    Write-Host ("   同期状態   : リモートに {0} commit(s) の更新あり" -f $behind) -ForegroundColor Yellow
} else {
    Write-Host "   同期状態   : 最新" -ForegroundColor Gray
}

# ---- pull は「リモートに更新がある時だけ」確認 ----
if ([int]$behind -gt 0) {
    Write-Host ""
    $ans = Read-Host "   最新を取得しますか？ [Y/N]"
    if ($ans -match '^[Yy]') {
        git pull --ff-only
    }
}

# ---- README / TODO / CHANGELOG 表示 ----
Show-Docs $proj.Path

# ---- Claude Code 起動 ----
Write-Host ""
$launched = Start-Claude

# =====================================================================
#  終了後：変更があれば GitHub へ保存するか確認（GitHubプロジェクトのみ）
# =====================================================================
if ($launched) {
    Set-Location $proj.Path
    $after = git status --porcelain
    if ([string]::IsNullOrWhiteSpace($after)) {
        Write-Host ""
        Write-Host "   変更なし。GitHubへの保存は不要です。" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "===================================" -ForegroundColor Yellow
        Write-Host ("   {0}   未保存の変更があります" -f $proj.Disp) -ForegroundColor Yellow
        Write-Host "===================================" -ForegroundColor Yellow
        git status --short
        Write-Host ""
        $save = Read-Host "   GitHubへ保存しますか？ [Y/N]"
        if ($save -match '^[Yy]') {
            $msg = Read-Host "   コミットメッセージ"
            if ([string]::IsNullOrWhiteSpace($msg)) {
                Write-Host "   メッセージが空のため中止しました（コミットしていません）。" -ForegroundColor Red
            } else {
                git add -A
                # 日本語メッセージを文字化けさせないため UTF-8(BOMなし) 一時ファイル経由でコミット
                $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("devcommit_" + [guid]::NewGuid().ToString('N') + ".txt")
                [System.IO.File]::WriteAllText($tmp, $msg, (New-Object System.Text.UTF8Encoding($false)))
                git commit -F $tmp
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                if ($LASTEXITCODE -eq 0) {
                    git push
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "   GitHubへ保存しました。" -ForegroundColor Green
                    } else {
                        Write-Host "   push に失敗しました。手動で確認してください。" -ForegroundColor Red
                    }
                } else {
                    Write-Host "   commit に失敗しました。" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "   保存しませんでした（変更はローカルに残っています）。" -ForegroundColor Gray
        }
    }
}
