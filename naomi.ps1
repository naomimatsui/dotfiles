# =====================================================================
#  naomi.ps1  —  Naomi Launcher
#  使い方: PowerShell で  naomi  と入力（naomi.cmd 経由）／デスクトップの
#         「Naomi Launcher」ショートカットからも起動。
#
#  方針:
#   - dev ランチャーとは別物。dev.ps1 / dev.cmd は一切変更しない。
#   - Google Drive のドライブ文字は自動検出（G:固定に依存しない）。
#   - フォルダのパス上書きは各PCの %LOCALAPPDATA%\NaomiLauncher\config.json に保存。
#   - 元ファイルは移動/削除/改名しない。管理者権限不要。エラーは日本語表示。
#   - メニューはループ。処理後はメニューへ戻る（すぐ閉じない）。
# =====================================================================

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---- 各PC専用の保存場所 ----
$AppDir     = Join-Path $env:LOCALAPPDATA 'NaomiLauncher'
$ConfigPath = Join-Path $AppDir 'config.json'
if (-not (Test-Path $AppDir)) { New-Item -ItemType Directory -Force -Path $AppDir | Out-Null }

# ---- Google Drive ルートの自動検出（マイドライブ / My Drive を探す） ----
function Find-GoogleDrive {
    foreach ($d in [char[]](67..90)) {          # C..Z
        foreach ($sub in @('マイドライブ', 'My Drive')) {
            $p = ('{0}:\{1}' -f $d, $sub)
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

# ---- 上書き設定の読み書き（明示的に指定した分だけ保存＝ドライブ文字差に強い） ----
function Load-Overrides {
    $o = @{}
    if (Test-Path $ConfigPath) {
        try {
            $j = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.overrides) {
                foreach ($p in $j.overrides.PSObject.Properties) { $o[$p.Name] = $p.Value }
            }
        } catch { }
    }
    return $o
}
function Save-Overrides {
    $obj = [pscustomobject]@{
        computer_name = $env:COMPUTERNAME
        gdrive_root   = $script:GDrive
        overrides     = ([pscustomobject]$script:Overrides)
    }
    try { $obj | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8 }
    catch { Write-Host ("   設定の保存に失敗しました: {0}" -f $_.Exception.Message) -ForegroundColor Red }
}

$script:GDrive    = Find-GoogleDrive
$script:Overrides = Load-Overrides

# 既定パス（Google Drive基準）に、明示的な上書きがあれば反映して返す
function Get-Folders {
    $g = $script:GDrive
    $f = @{
        naomi_ai = if ($g) { Join-Path $g '直美AI' }                else { '' }
        threads  = if ($g) { Join-Path $g 'THREADSおみちゃんねる' } else { '' }
        vault    = if ($g) { Join-Path $g 'Obsidian Vault' }        else { '' }
        note     = ''
    }
    foreach ($k in @('naomi_ai', 'threads', 'vault', 'note')) {
        if ($script:Overrides.ContainsKey($k) -and $script:Overrides[$k]) { $f[$k] = $script:Overrides[$k] }
    }
    return $f
}

# ---- claude.exe 解決（PATH → Store版 → 通常版）。dev.ps1 とは独立の複製。 ----
function Resolve-ClaudeExe {
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) { return $cmd.Source }
    $storePackage = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($storePackage) {
        $dir = Join-Path $storePackage.FullName 'LocalCache\Roaming\Claude\claude-code'
        if (Test-Path $dir) {
            $v = Get-ChildItem $dir -Directory -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
            if ($v) { $exe = Join-Path $v.FullName 'claude.exe'; if (Test-Path $exe) { return $exe } }
        }
    }
    $dir = Join-Path $env:APPDATA 'Claude\claude-code'
    if (Test-Path $dir) {
        $v = Get-ChildItem $dir -Directory -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
        if ($v) { $exe = Join-Path $v.FullName 'claude.exe'; if (Test-Path $exe) { return $exe } }
    }
    return $null
}

function Start-ClaudeIn($path, $label) {
    if (-not $path) { Write-Host ("   {0} のフォルダが設定されていません。" -f $label) -ForegroundColor Yellow; return }
    if (-not (Test-Path $path)) {
        Write-Host ("   フォルダが見つかりません: {0}" -f $path) -ForegroundColor Red
        Write-Host "   （8)設定 でフォルダを指定できます。Google Driveのマウントも確認してください）" -ForegroundColor DarkGray
        return
    }
    Set-Location $path
    Write-Host ("   作業フォルダ: {0}" -f $path) -ForegroundColor Gray
    if (Test-Path (Join-Path $path 'CLAUDE.md')) {
        Write-Host "   CLAUDE.md を検出（内容を利用できる状態で起動します）" -ForegroundColor DarkGray
    }
    $exe = Resolve-ClaudeExe
    if (-not $exe) {
        Write-Host "   claude が見つかりません（Store版/通常版/PATHいずれも）。" -ForegroundColor Red
        return
    }
    Write-Host "   Claude Code を起動します..." -ForegroundColor Cyan
    & $exe
}

function Open-Obsidian($vaultPath) {
    if (-not $vaultPath -or -not (Test-Path $vaultPath)) {
        Write-Host ("   Obsidian Vault が見つかりません: {0}" -f $vaultPath) -ForegroundColor Red
        return
    }
    $vaultName = Split-Path $vaultPath -Leaf
    $uri = "obsidian://open?vault=$([uri]::EscapeDataString($vaultName))"
    try {
        Start-Process $uri -ErrorAction Stop | Out-Null
        Write-Host "   Obsidian で開きました。" -ForegroundColor Gray
    } catch {
        Start-Process explorer.exe $vaultPath | Out-Null
        Write-Host "   Obsidianアプリが見つからないため、フォルダを開きました。" -ForegroundColor Yellow
    }
}

function Run-Search($naomiPath) {
    if (-not $naomiPath -or -not (Test-Path $naomiPath)) { Write-Host "   直美AI フォルダが見つかりません。" -ForegroundColor Red; return }
    $bat = Join-Path $naomiPath 'search_naomi_ai.bat'
    $py  = Join-Path $naomiPath 'scripts\search_index.py'
    if (Test-Path $bat) {
        Write-Host "   ファイル検索を起動します（日本語で入力できます）..." -ForegroundColor Cyan
        Start-Process -FilePath $bat -Wait
    } elseif (Test-Path $py) {
        Write-Host "   ファイル検索を起動します（日本語で入力できます）..." -ForegroundColor Cyan
        Push-Location $naomiPath
        try { python 'scripts\search_index.py' } finally { Pop-Location }
    } else {
        Write-Host "   検索機能が見つかりません（search_naomi_ai.bat / scripts\search_index.py）。" -ForegroundColor Red
    }
}

function Update-Index($naomiPath) {
    if (-not $naomiPath -or -not (Test-Path $naomiPath)) { Write-Host "   直美AI フォルダが見つかりません。" -ForegroundColor Red; return }
    $bat = Join-Path $naomiPath 'update_naomi_ai.bat'
    if (-not (Test-Path $bat)) { Write-Host "   更新スクリプトが見つかりません（update_naomi_ai.bat）。" -ForegroundColor Red; return }
    Write-Host ""
    Write-Host "   直美AIの索引を更新しますか？" -ForegroundColor Yellow
    Write-Host "     1) はい"
    Write-Host "     2) いいえ"
    $a = Read-Host "   番号を入力してください"
    if ($a -eq '1') {
        Write-Host "   更新を実行します（別ウィンドウ・終了までお待ちください）..." -ForegroundColor Cyan
        Start-Process -FilePath $bat -Wait
        Write-Host ""
        Write-Host "   索引の更新が終わりました。" -ForegroundColor Green
    } else {
        Write-Host "   更新をキャンセルしました。" -ForegroundColor Gray
    }
}

function Open-FolderMenu {
    $f = Get-Folders
    Write-Host ""
    Write-Host "   -- フォルダを開く --"
    Write-Host "   1) 直美AI"
    Write-Host "   2) Threads・おみちゃんねる"
    Write-Host "   3) Obsidian Vault"
    Write-Host "   4) Note用"
    Write-Host "   0) 戻る"
    $a = Read-Host "   番号を入力してください"
    if ($a -eq '0' -or [string]::IsNullOrWhiteSpace($a)) { return }
    $target = switch ($a) { '1' { $f.naomi_ai } '2' { $f.threads } '3' { $f.vault } '4' { $f.note } default { $null } }
    if ($null -eq $target) { Write-Host "   無効な番号です。" -ForegroundColor Red; return }
    if ($target -and (Test-Path $target)) {
        Start-Process explorer.exe $target | Out-Null
        Write-Host ("   開きました: {0}" -f $target) -ForegroundColor Gray
    } else {
        Write-Host "   そのフォルダは未設定、または見つかりません。" -ForegroundColor Yellow
    }
}

function Pick-Folder($desc) {
    try {
        $sh = New-Object -ComObject Shell.Application
        $f = $sh.BrowseForFolder(0, $desc, 0, 0)
        if ($f) { return $f.Self.Path }
    } catch { }
    return $null
}

function Set-Config {
    $items = @(
        @{ key = 'naomi_ai'; name = '直美AI' },
        @{ key = 'threads';  name = 'Threads' },
        @{ key = 'vault';    name = 'Obsidian Vault' },
        @{ key = 'note';     name = 'Note用' }
    )
    Write-Host ""
    Write-Host "   -- 現在のフォルダ設定 --"
    $f = Get-Folders
    for ($i = 0; $i -lt $items.Count; $i++) {
        $v = $f[$items[$i].key]
        $st = if ($v -and (Test-Path $v)) { 'OK' } elseif ($v) { '見つからない' } else { '未設定' }
        Write-Host ("   {0}) {1,-16} {2}  [{3}]" -f ($i + 1), $items[$i].name, $v, $st)
    }
    Write-Host "   0) 戻る"
    $a = Read-Host "   変更する番号を入力（0で戻る）"
    if ($a -eq '0' -or [string]::IsNullOrWhiteSpace($a)) { return }
    $idx = ($a -as [int]) - 1
    if ($null -eq ($a -as [int]) -or $idx -lt 0 -or $idx -ge $items.Count) { Write-Host "   無効な番号です。" -ForegroundColor Red; return }
    $key = $items[$idx].key
    Write-Host "   フォルダ選択画面を開きます..." -ForegroundColor Cyan
    $picked = Pick-Folder ($items[$idx].name + ' のフォルダを選択してください')
    if ($picked) {
        $script:Overrides[$key] = $picked
        Save-Overrides
        Write-Host ("   保存しました: {0} = {1}" -f $items[$idx].name, $picked) -ForegroundColor Green
    } else {
        Write-Host "   選択がキャンセルされました（変更なし）。" -ForegroundColor Gray
    }
}

# =====================================================================
#  メニュー・ループ
# =====================================================================
while ($true) {
    Write-Host ""
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "       Naomi Launcher"           -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) 直美AI"
    Write-Host "  2) Threads・おみちゃんねる"
    Write-Host "  3) Obsidian Vault"
    Write-Host "  4) Note用"
    Write-Host "  5) ファイル検索"
    Write-Host "  6) 直美AIの索引を更新"
    Write-Host "  7) フォルダを開く"
    Write-Host "  8) 設定"
    Write-Host "  0) 終了"
    Write-Host ""
    $sel = Read-Host "  番号を入力してください"

    if ($sel -eq '0' -or $sel -eq 'q') { Write-Host "   終了します。" -ForegroundColor Gray; break }

    try {
        $f = Get-Folders
        switch ($sel) {
            '1' { Start-ClaudeIn $f.naomi_ai '直美AI' }
            '2' { Start-ClaudeIn $f.threads 'Threads・おみちゃんねる' }
            '3' { Open-Obsidian $f.vault }
            '4' {
                if ($f.note -and (Test-Path $f.note)) { Start-ClaudeIn $f.note 'Note用' }
                else { Write-Host "   Note用フォルダが設定されていません。" -ForegroundColor Yellow; Write-Host "   （8)設定 で指定できます）" -ForegroundColor DarkGray }
            }
            '5' { Run-Search $f.naomi_ai }
            '6' { Update-Index $f.naomi_ai }
            '7' { Open-FolderMenu }
            '8' { Set-Config }
            default { Write-Host "   無効な番号です。" -ForegroundColor Red }
        }
    } catch {
        Write-Host ("   エラーが発生しました: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }

    Write-Host ""
    [void](Read-Host "   Enterキーでメニューに戻ります")
}
