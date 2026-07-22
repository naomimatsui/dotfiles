# =====================================================================
#  dev.ps1  —  Claude Code プロジェクトランチャー  (dev 2.2)
#
#  ⚠️ 2026-07-22：これは旧ランチャーです。通常は使いません。
#     日常の起動口は Vaultルートの claude-start.cmd
#     （デスクトップ「★Claude Code（会社）」）と Naomi Launcher(naomi.ps1) の2本。
#     デスクトップの旧ショートカットは「_旧_使わない_Claude Codeランチャー」に改名済み。
#
#  方針:
#   - Obsidian Vault は「普段使いの中心」。git操作は一切しない（Obsidian Syncが同期する）。
#   - GitHubプロジェクトを選んだ日だけ、開始時pull・終了時push（どちらも確認付き）。
#   - 固定パス(adoni等)は使わない。GitHubルート=$env:USERPROFILE\GitHub。
#   - Claude起動は Store版 / 通常版 / PATH の3段フォールバック（家PC・会社PC対応）。
#   - 起動時に自動で dotfiles を git pull（更新確認）。dev.ps1 自身が更新された時は
#     無理に再読み込みせず、安全に終了して再起動を促す。
#   - メニューはループする。0=ランチャー更新（手動・同じ処理） / q=終了。
# =====================================================================

# 日本語表示のため入出力を UTF-8 に
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root      = Join-Path $env:USERPROFILE 'GitHub'

# Vault は Obsidian Sync のローカル(%USERPROFILE%\ObsidianVault)が正。
# G:\マイドライブ\Obsidian Vault は 2026-07-18 に凍結したバックアップ＝開いてはいけない。
# （naomi.ps1 の Get-Folders と同じ方針。2026-07-22 修正）
$localVault = Join-Path $env:USERPROFILE 'ObsidianVault'
$VaultPath  = if (Test-Path $localVault) { $localVault } else { '' }

$HomeAiPath = if ($VaultPath) { Join-Path $VaultPath 'App Ideas\HomeAI Project' } else { '' }
$DotfilesPath = Join-Path $Root 'dotfiles'

# 直美AI も C: が正（2026-07-20 に G: から %USERPROFILE%\NaomiAI へ移設済み）
$localNaomiAI = Join-Path $env:USERPROFILE 'NaomiAI'
$NaomiAiPath  = if (Test-Path $localNaomiAI) { $localNaomiAI } else { '' }

# HomeAI がGitHubリポになったか判定する候補
$HomeAiRepoCandidates = @('homeai', 'home-ai', 'HomeAI')

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
    #    npm の .ps1 / .cmd シムは、パイプ入力があると $input を claude.exe に流し込み、
    #    claude が --print モードに入って「プロンプトが無い」エラーになる（対話起動できない）。
    #    そこでシムを避け、実体の claude.exe（node_modules\...\bin\claude.exe）を優先する。
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
        $src = $cmd.Source
        if ($src -match '\.(ps1|cmd)$') {
            $shimDir = Split-Path $src -Parent
            $realExe = Join-Path $shimDir 'node_modules\@anthropic-ai\claude-code\bin\claude.exe'
            if (Test-Path $realExe) { return $realExe }
            # 実体が見つからなければ、下の Store版/通常版フォールバックへ進む
        } else {
            return $src   # 既に .exe など実体
        }
    }

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

# --- Obsidian でノートを開く（vault名+file の obsidian:// URI。失敗時は既定アプリで開く） ---
function Open-VaultNote($vaultRoot, $rel) {
    $full = Join-Path $vaultRoot $rel
    if (-not (Test-Path $full)) {
        Write-Host ("   スキップ（無し）: {0}" -f $rel) -ForegroundColor DarkGray
        return
    }
    $vaultName = Split-Path $vaultRoot -Leaf
    $uri = "obsidian://open?vault=$([uri]::EscapeDataString($vaultName))&file=$([uri]::EscapeDataString($rel))"
    try {
        Start-Process $uri -ErrorAction Stop | Out-Null
    } catch {
        try { Invoke-Item -LiteralPath $full -ErrorAction Stop } catch {
            Write-Host ("   開けませんでした: {0}" -f $rel) -ForegroundColor DarkGray
            return
        }
    }
    Write-Host ("   開きました: {0}" -f $rel) -ForegroundColor Gray
    Start-Sleep -Milliseconds 500   # Obsidianが順番にタブを開くための小休止
}

# =====================================================================
#  ★ ランチャー更新：dotfiles を git pull（起動時の自動更新・0番の手動更新で共用）
#     戻り値: 'uptodate' | 'updated' | 'updated-self' | 'failed'
#     - ローカル変更に対して restore / reset / 削除は一切しない（--ff-only）。
#     - 失敗してもランチャーは終了せず、日本語で原因を表示して続行する。
#     - dev.ps1 自身が更新された場合は 'updated-self' を返し、呼び出し側が安全終了する。
# =====================================================================
function Invoke-LauncherUpdate {
    Write-Host ""
    Write-Host "   ランチャーの更新を確認しています..." -ForegroundColor Cyan

    if (-not (Test-Path (Join-Path $DotfilesPath '.git'))) {
        Write-Host ("   dotfiles リポジトリが見つかりません: {0}" -f $DotfilesPath) -ForegroundColor Red
        Write-Host "   更新はスキップして、このままメニューへ進みます。" -ForegroundColor Yellow
        return 'failed'
    }

    Push-Location $DotfilesPath
    try {
        # ローカル変更の有無を確認（勝手に restore / reset / 削除はしない）
        $dirty  = git status --porcelain
        $before = (git rev-parse HEAD 2>$null)

        # git の出力は画面に見せるが、関数の戻り値には混ぜない（Out-Host で分離）
        git pull --ff-only | Out-Host
        $code = $LASTEXITCODE

        if ($code -ne 0) {
            Write-Host ""
            Write-Host "   更新の取得に失敗しました（ランチャーは終了せず続行します）。" -ForegroundColor Red
            if (-not [string]::IsNullOrWhiteSpace($dirty)) {
                Write-Host "   原因：このPCのローカルに未保存の変更があるため、更新できませんでした。" -ForegroundColor Yellow
                Write-Host "   対処：変更を保存（コミット）するか、元に戻してから、もう一度お試しください。" -ForegroundColor Yellow
                Write-Host "        （restore / reset / 削除など、あなたの変更を勝手に消すことはしません）" -ForegroundColor DarkGray
            } else {
                Write-Host "   ネットワークや GitHub の状態を確認して、もう一度お試しください。" -ForegroundColor Yellow
            }
            return 'failed'
        }

        $after = (git rev-parse HEAD 2>$null)
        if ($before -eq $after) {
            Write-Host "   最新の状態です。" -ForegroundColor Green
            return 'uptodate'
        }

        # 新しいコミットが来た → dev.ps1 自身が更新されたか判定
        $changed = git diff --name-only $before $after 2>$null
        $selfUpdated = $false
        foreach ($line in ($changed -split "`r?`n")) {
            if ($line.Trim() -eq 'dev.ps1') { $selfUpdated = $true; break }
        }

        Write-Host "   ランチャーを更新しました。" -ForegroundColor Green
        if ($selfUpdated) { return 'updated-self' } else { return 'updated' }
    } finally {
        Pop-Location
    }
}

# --- ランチャー自身が更新された時の安全終了メッセージ（無理に再読み込みしない） ---
function Show-RestartNotice {
    Write-Host ""
    Write-Host "===================================" -ForegroundColor Yellow
    Write-Host "   ランチャーが更新されたため、いったん終了して再起動してください。" -ForegroundColor Yellow
    Write-Host "===================================" -ForegroundColor Yellow
    Write-Host "   （安全のため実行中のランチャーはここで終了します。もう一度起動すると最新版で動きます）" -ForegroundColor DarkGray
}

# =====================================================================
#  メニュー構築：Obsidian Vault を先頭に、既知プロジェクトを希望順、
#  未知の GitHub リポは末尾に自動追加。（毎回呼び出して最新状態を反映）
# =====================================================================
function Build-Menu {
    # HomeAI は GitHubリポが出来るまで Obsidianプロジェクト(git操作なし)として扱い、
    # リポが GitHub\ に出来たら自動で git 扱い（pull/push対象）へ切り替える。
    $homeAiRepo = $null
    foreach ($c in $HomeAiRepoCandidates) {
        $cand = Join-Path $Root $c
        if (Test-Path (Join-Path $cand '.git')) { $homeAiRepo = $cand; break }
    }
    if ($homeAiRepo) {
        $homeAiEntry = [ordered]@{ Kind = 'git';   Disp = 'HomeAI'; Path = $homeAiRepo }
    } else {
        $homeAiEntry = [ordered]@{ Kind = 'nogit'; Disp = 'HomeAI'; Path = $HomeAiPath }
    }

    $layout = @(
        [ordered]@{ Kind = 'obsidian'; Disp = 'Obsidian Vault'; Path = $VaultPath }
        [ordered]@{ Kind = 'git';      Disp = 'AKARI';          Folder = 'akari' }
        $homeAiEntry
        [ordered]@{ Kind = 'git';      Disp = '秒合わせ';        Folder = 'byou-awase' }
        [ordered]@{ Kind = 'git';      Disp = '予算カゴ';        Folder = 'budget-cago' }
        [ordered]@{ Kind = 'git';      Disp = 'MARINE CORE';     Folder = 'marinecore' }
        [ordered]@{ Kind = 'naomiai';  Disp = '直美AI';          Path = $NaomiAiPath }
    )

    $menu = @()
    foreach ($e in $layout) {
        if ($e.Kind -eq 'git') {
            # Folder指定なら GitHubルート基準、Path指定ならそのまま（HomeAIがリポ化した場合など）
            $path = if ($e.Contains('Folder') -and $e.Folder) { Join-Path $Root $e.Folder } else { $e.Path }
            $menu += [pscustomobject]@{ Disp = $e.Disp; Path = $path; Kind = 'git'; Exists = (Test-Path (Join-Path $path '.git')) }
        } else {
            $menu += [pscustomobject]@{ Disp = $e.Disp; Path = $e.Path; Kind = $e.Kind; Exists = (Test-Path $e.Path) }
        }
    }

    # 既知以外の GitHub リポを自動追加（dotfiles は開発対象外・HomeAI候補は二重表示防止で除外）
    $knownFolders = @('akari', 'byou-awase', 'budget-cago', 'marinecore') + $HomeAiRepoCandidates
    $extra = Get-ChildItem -Path $Root -Directory -ErrorAction SilentlyContinue |
        Where-Object { (Test-Path (Join-Path $_.FullName '.git')) -and $_.Name -ne 'dotfiles' -and ($knownFolders -notcontains $_.Name) } |
        Sort-Object Name
    foreach ($x in $extra) {
        $menu += [pscustomobject]@{ Disp = (Get-Disp $x.Name); Path = $x.FullName; Kind = 'git'; Exists = $true }
    }

    return $menu
}

# =====================================================================
#  選択したプロジェクトを開く（Claude起動まで含む）
# =====================================================================
function Invoke-Project($proj) {

    # -----------------------------------------------------------------
    #  分岐A：Obsidian Vault（git操作なし）
    # -----------------------------------------------------------------
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

        # 起動時に運用ファイルを順番にObsidianで開く（家・会社とも同じ動作）
        Write-Host ""
        Write-Host "   運用ファイルを順番に開きます（PROJECTS → TODAY → WORKLOG）..." -ForegroundColor Cyan
        foreach ($rel in @('PROJECTS.md', 'TODAY.md', 'WORKLOG.md')) {
            Open-VaultNote $proj.Path $rel
        }

        Write-Host ""
        [void](Start-Claude)
        # 終了後も git 操作はしない
        return
    }

    # -----------------------------------------------------------------
    #  分岐 HomeAI：企画フォルダを開くだけ（git操作なし）
    # -----------------------------------------------------------------
    if ($proj.Kind -eq 'nogit') {
        if (-not (Test-Path $proj.Path)) {
            Write-Host ""
            Write-Host ("   企画フォルダが見つかりません: {0}" -f $proj.Path) -ForegroundColor Red
            return
        }
        Set-Location $proj.Path
        Write-Host ""
        Write-Host ("   {0}：Obsidianプロジェクトとして開きます（GitHubリポ未作成 / git操作なし）" -f $proj.Disp) -ForegroundColor Green
        Write-Host "   ※ GitHub\ にリポができたら、次回から自動でgit(pull/push)対象になります。" -ForegroundColor DarkGray
        Write-Host ("   場所: {0}" -f $proj.Path) -ForegroundColor DarkGray
        Show-Docs $proj.Path
        Write-Host ""
        [void](Start-Claude)
        return
    }

    # -----------------------------------------------------------------
    #  分岐：直美AI（Google Drive内・ファイル検索/差分更新。git操作なし）
    # -----------------------------------------------------------------
    if ($proj.Kind -eq 'naomiai') {
        if (-not (Test-Path $proj.Path)) {
            Write-Host ""
            Write-Host ("   直美AI フォルダが見つかりません: {0}" -f $proj.Path) -ForegroundColor Red
            Write-Host "   Google Drive がマウントされているか確認してください。" -ForegroundColor Red
            return
        }
        Set-Location $proj.Path
        Write-Host ""
        Write-Host "===================================" -ForegroundColor Green
        Write-Host "   直美AI（ファイル検索）" -ForegroundColor Green
        Write-Host "===================================" -ForegroundColor Green
        Write-Host ("   場所: {0}" -f $proj.Path) -ForegroundColor DarkGray
        Write-Host "   ※ プログラムは共有・DBは各PCの %LOCALAPPDATA%\NaomiAI に保存（git操作なし）" -ForegroundColor DarkGray

        # 初回判定：このPCに索引（config.json / naomi_ai.db）がまだ無いか
        $naomiHome = Join-Path $env:LOCALAPPDATA 'NaomiAI'
        $cfg = Join-Path $naomiHome 'config.json'
        $db  = Join-Path $naomiHome 'naomi_ai.db'
        $firstTime = (-not (Test-Path $cfg)) -or (-not (Test-Path $db))

        if ($firstTime) {
            Write-Host ""
            Write-Host "   このPCでは、まだ索引が作られていないようです（初回）。" -ForegroundColor Yellow
            $ans = Read-Host "   今すぐ update_naomi_ai.bat を実行して初回設定＆索引を作りますか？ [Y/N]"
            if ($ans -match '^[Yy]') {
                $bat = Join-Path $proj.Path 'update_naomi_ai.bat'
                if (Test-Path $bat) {
                    Write-Host "   update_naomi_ai.bat を実行します（別ウィンドウ・終了までお待ちください）..." -ForegroundColor Cyan
                    Start-Process -FilePath $bat -Wait
                } else {
                    Write-Host "   update_naomi_ai.bat が見つかりません。" -ForegroundColor Red
                }
            } else {
                Write-Host "   索引作成はスキップしました（あとで update_naomi_ai.bat から実行できます）。" -ForegroundColor Gray
            }
        } else {
            Write-Host ""
            Write-Host "   索引あり。最新にしたいときは update_naomi_ai.bat（差分更新）をどうぞ。" -ForegroundColor Gray
        }

        # 直美AIプロジェクトを開く（フォルダをエクスプローラー表示＋Claude Code起動）
        Write-Host ""
        Write-Host "   直美AI フォルダを開きます..." -ForegroundColor Cyan
        Start-Process explorer.exe $proj.Path
        Show-Docs $proj.Path
        Write-Host ""
        [void](Start-Claude)
        return
    }

    # -----------------------------------------------------------------
    #  分岐B：GitHubプロジェクト
    # -----------------------------------------------------------------
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

    # -----------------------------------------------------------------
    #  終了後：変更があれば GitHub へ保存するか確認（GitHubプロジェクトのみ）
    # -----------------------------------------------------------------
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
    return
}

# =====================================================================
#  起動時：自動でランチャー更新をチェック（家PC・会社PC共通）
#    - dotfiles へ移動して git pull（--ff-only）。
#    - dev.ps1 自身が更新された時は、無理に再読み込みせず安全に終了して再起動を促す。
# =====================================================================
Set-Location $DotfilesPath
$startupUpdate = Invoke-LauncherUpdate
if ($startupUpdate -eq 'updated-self') {
    Show-RestartNotice
    return
}

# =====================================================================
#  メインループ：メニュー表示 → 選択 → 実行 → メニューへ戻る
#    0 = ランチャー更新（手動・起動時と同じ処理） / q（または空Enter）= 終了
# =====================================================================
while ($true) {
    $menu = Build-Menu

    # ---- 一覧表示 ----
    Write-Host ""
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host "   Claude Code  プロジェクト選択" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   0)  ランチャー更新（dotfiles を git pull）" -ForegroundColor DarkCyan
    for ($i = 0; $i -lt $menu.Count; $i++) {
        $m = $menu[$i]
        $tag = ''
        if     ($m.Kind -eq 'obsidian') { $tag = '  [Obsidian / git無]' }
        elseif ($m.Kind -eq 'nogit')    { $tag = '  [Obsidianプロジェクト / git無]' }
        elseif ($m.Kind -eq 'naomiai')  { $tag = '  [直美AI / 差分更新・検索]' }
        if (-not $m.Exists) {
            if ($m.Kind -eq 'git') { $tag = '  [リポジトリ未作成]' } else { $tag = '  [見つかりません]' }
        }
        Write-Host ("   {0})  {1}{2}" -f ($i + 1), $m.Disp, $tag)
    }
    Write-Host ""

    $sel = Read-Host "   番号を入力 (0=ランチャー更新 / q=終了)"

    # ---- 終了 ----
    if ($sel -eq 'q' -or [string]::IsNullOrWhiteSpace($sel)) {
        Write-Host ""
        Write-Host "   終了します。" -ForegroundColor Gray
        break
    }

    # ---- 0：手動でランチャー更新 → メニューへ戻る（自身が更新されたら安全終了）----
    if ($sel -eq '0') {
        $manualUpdate = Invoke-LauncherUpdate
        if ($manualUpdate -eq 'updated-self') {
            Show-RestartNotice
            break
        }
        continue
    }

    # ---- 数字の検証 ----
    $idx = ($sel -as [int]) - 1
    if ($null -eq ($sel -as [int]) -or $idx -lt 0 -or $idx -ge $menu.Count) {
        Write-Host "   無効な番号です。" -ForegroundColor Red
        continue
    }

    # ---- プロジェクトを開く → 戻ってきたらメニューへ ----
    Invoke-Project $menu[$idx]
}
