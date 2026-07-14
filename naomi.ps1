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
#   - 起動時に全ドライブを再走査しない（軽い確認のみ）。
# =====================================================================

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$AppDir     = Join-Path $env:LOCALAPPDATA 'NaomiLauncher'
$ConfigPath = Join-Path $AppDir 'config.json'
if (-not (Test-Path $AppDir)) { New-Item -ItemType Directory -Force -Path $AppDir | Out-Null }

# ---- Google Drive ルートの自動検出（マイドライブ / My Drive を探す） ----
function Find-GoogleDrive {
    foreach ($d in [char[]](67..90)) {
        foreach ($sub in @('マイドライブ', 'My Drive')) {
            $p = ('{0}:\{1}' -f $d, $sub)
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

# ---- 上書き設定（明示指定分だけ保存＝ドライブ文字差に強い） ----
function Load-Overrides {
    $o = @{}
    if (Test-Path $ConfigPath) {
        try {
            $j = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.overrides) { foreach ($p in $j.overrides.PSObject.Properties) { $o[$p.Name] = $p.Value } }
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
    # npm の .ps1 / .cmd シムは --print モード誤起動の原因になるので、実体の claude.exe を優先（別セッションの修正を継承）。
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
        $src = $cmd.Source
        if ($src -match '\.(ps1|cmd)$') {
            $shimDir = Split-Path $src -Parent
            $realExe = Join-Path $shimDir 'node_modules\@anthropic-ai\claude-code\bin\claude.exe'
            if (Test-Path $realExe) { return $realExe }
        } else {
            return $src
        }
    }
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
        Write-Host ("   {0} のフォルダが見つかりません: {1}" -f $label, $path) -ForegroundColor Red
        Write-Host "   （7)設定 でフォルダを指定できます。Google Driveのマウントも確認してください）" -ForegroundColor DarkGray
        return
    }
    Set-Location $path
    Write-Host ("   作業フォルダ: {0}" -f $path) -ForegroundColor Gray
    if (Test-Path (Join-Path $path 'CLAUDE.md')) {
        Write-Host "   CLAUDE.md を検出（このプロジェクトのルールを利用できる状態で起動します）" -ForegroundColor DarkGray
    }
    $exe = Resolve-ClaudeExe
    if (-not $exe) { Write-Host "   claude が見つかりません（Store版/通常版/PATHいずれも）。" -ForegroundColor Red; return }
    Write-Host "   Claude Code を起動します..." -ForegroundColor Cyan
    & $exe
}

function Pick-Folder($desc) {
    try {
        $sh = New-Object -ComObject Shell.Application
        $f = $sh.BrowseForFolder(0, $desc, 0, 0)
        if ($f) { return $f.Self.Path }
    } catch { }
    return $null
}

# ---- Obsidian で「指定パスのファイル」を開く（path指定なので、そのVaultを確実に開く。
#      C:や"最後に開いたVault"には影響されない） ----
function Open-ObsidianFile($fullPath) {
    if (-not (Test-Path $fullPath)) { return $false }
    $uri = "obsidian://open?path=$([uri]::EscapeDataString($fullPath))"
    try { Start-Process $uri -ErrorAction Stop | Out-Null; return $true }
    catch { try { Invoke-Item -LiteralPath $fullPath -ErrorAction Stop; return $true } catch { return $false } }
}

# ---- 今日の仕事.md を用意（自動日付・前日未完了の引き継ぎ・履歴保持） ----
function Ensure-TodaysWork($path) {
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $tmpl = @(
        "### 最優先", "- [ ] Threads投稿", "- [ ] MARINE CORE", "- [ ] ショップチャンネル",
        "### AI・アプリ", "- [ ] 直美AI", "- [ ] HomeAI",
        "### 連絡", "- [ ] メール返信", "- [ ] LINE返信",
        "### 思いついたこと", "- [ ] ",
        "### 今日終わったこと", "- [ ] ")
    try {
        if (-not (Test-Path $path)) {
            $body = (@("# 今日の仕事", "", "## $today") + $tmpl + @("")) -join "`r`n"
            [System.IO.File]::WriteAllText($path, $body, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host ("   今日の仕事.md を新規作成しました（{0}）。" -f $today) -ForegroundColor Gray
            return
        }
        $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8
        if ($content -match "(?m)^##\s+$([regex]::Escape($today))\b") { return }  # 既に今日ぶんあり

        # 直近（先頭）の日付セクションから未完了 [ ] を収集（今日終わったこと は除外）
        $carry = @(); $inTop = $false; $inDone = $false; $seenDate = $false
        foreach ($ln in ($content -split "`r?`n")) {
            if ($ln -match '^##\s+\d{4}-\d{2}-\d{2}') {
                if ($seenDate) { break }
                $seenDate = $true; $inTop = $true; $inDone = $false; continue
            }
            if ($inTop) {
                if ($ln -match '^###\s*今日終わったこと') { $inDone = $true; continue }
                elseif ($ln -match '^###') { $inDone = $false; continue }
                if (-not $inDone -and $ln -match '^\s*-\s*\[\s\]\s+(\S.*)$') { $carry += $matches[1].Trim() }
            }
        }
        $newSection = @("## $today") + $tmpl
        if ($carry.Count -gt 0) {
            Write-Host ("   前日の未完了タスクが {0} 件あります。今日に引き継ぎますか？ [Y=はい / N=いいえ]" -f $carry.Count) -ForegroundColor Yellow
            $carry | ForEach-Object { Write-Host ("     ・{0}" -f $_) -ForegroundColor DarkGray }
            if ((Read-Host "   引き継ぐ") -match '^[YyＹｙ]') {
                $newSection += "### 繰り越し（前日の未完了）"
                foreach ($c in $carry) { $newSection += "- [ ] $c" }
            }
        }
        $newTop = ($newSection -join "`r`n") + "`r`n`r`n"
        if ($content -match "(?s)^(#\s*今日の仕事[^\r\n]*\r?\n)(.*)$") {
            $out = $matches[1] + "`r`n" + $newTop + ($matches[2].TrimStart("`r", "`n"))
        } else {
            $out = "# 今日の仕事`r`n`r`n" + $newTop + $content
        }
        [System.IO.File]::WriteAllText($path, $out, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host ("   今日（{0}）の仕事を追加しました（前日ぶんは下に保持）。" -f $today) -ForegroundColor Gray
    } catch {
        Write-Host ("   今日の仕事.md の準備でエラー: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
}

# ---- 1) 今日の仕事（WORKLOG）：Google Drive上のVaultを確実に開く ----
function Open-TodaysWork {
    $vault = $null
    for ($i = 0; $i -lt 6; $i++) {
        $v = (Get-Folders).vault
        if ($v -and (Test-Path $v)) { $vault = $v; break }
        if ($i -eq 0) { Write-Host "   Google Driveの準備を待っています..." -ForegroundColor Yellow }
        Start-Sleep -Seconds 1
    }
    if (-not $vault) {
        Write-Host "   Obsidian Vault が見つかりませんでした。" -ForegroundColor Yellow
        Write-Host "   Obsidian Vaultを選択してください（フォルダ選択画面を開きます）。" -ForegroundColor Cyan
        $picked = Pick-Folder 'Obsidian Vault のフォルダを選択してください'
        if ($picked) { $script:Overrides['vault'] = $picked; Save-Overrides; $vault = $picked }
        else { Write-Host "   選択されませんでした。中止します。" -ForegroundColor Gray; return }
    }
    Write-Host ("   Vault: {0}" -f $vault) -ForegroundColor Gray
    $todo = Join-Path $vault '今日の仕事.md'
    Ensure-TodaysWork $todo
    $worklog = Join-Path $vault 'WORKLOG.md'
    if (Test-Path $worklog) { [void](Open-ObsidianFile $worklog) }   # 仕様2：WORKLOGを最初に
    else { [void](Open-ObsidianFile $vault); Write-Host "   WORKLOG.md が無いのでVaultを開きました。" -ForegroundColor DarkGray }
    Start-Sleep -Milliseconds 500
    [void](Open-ObsidianFile $todo)                                 # 続けて今日の仕事（前面に）
    Write-Host "   WORKLOG と 今日の仕事 を Obsidian で開きました。" -ForegroundColor Green
}

# ---- 5) ファイル検索（既存の search_naomi_ai.bat / search_index.py を利用） ----
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

# ---- 6) 索引更新（既存の差分更新 update_naomi_ai.bat を利用） ----
function Update-Index($naomiPath) {
    if (-not $naomiPath -or -not (Test-Path $naomiPath)) { Write-Host "   直美AI フォルダが見つかりません。" -ForegroundColor Red; return }
    $bat = Join-Path $naomiPath 'update_naomi_ai.bat'
    if (-not (Test-Path $bat)) { Write-Host "   更新スクリプトが見つかりません（update_naomi_ai.bat）。" -ForegroundColor Red; return }
    while ($true) {
        Write-Host ""
        Write-Host "   直美AIの索引を更新しますか？" -ForegroundColor Yellow
        Write-Host "     1) はい"
        Write-Host "     2) あとで"
        Write-Host "     3) 詳細を見る"
        Write-Host "     0) 戻る"
        $a = Read-Host "   番号を入力してください"
        if ($a -eq '1') {
            Write-Host "   更新を実行します（別ウィンドウ・差分のみ・バックアップとロックあり）..." -ForegroundColor Cyan
            Start-Process -FilePath $bat -Wait
            Write-Host "   索引の更新が終わりました。" -ForegroundColor Green
            return
        } elseif ($a -eq '2') {
            Write-Host "   あとで更新します。" -ForegroundColor Gray; return
        } elseif ($a -eq '0') {
            return
        } elseif ($a -eq '3') {
            Write-Host ""
            Write-Host "   ── 更新の詳細 ──" -ForegroundColor Gray
            Write-Host "   ・前回との差分だけ処理（新規 / 変更 / 消失=missing）。全件作り直しはしません。"
            Write-Host "   ・消失ファイルは削除せず status=missing に。再発見で active に戻ります。"
            Write-Host "   ・更新前に naomi_ai.db をバックアップ（7世代）。二重更新防止のロックあり。"
            Write-Host "   ・元ファイルは 変更/移動/削除 しません。オンライン専用は中身をDLしません。"
            $logdir = Join-Path $env:LOCALAPPDATA 'NaomiAI\logs'
            if (Test-Path $logdir) {
                $lg = Get-ChildItem $logdir -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($lg) { Write-Host ("   ・前回ログ: {0}" -f $lg.FullName) -ForegroundColor DarkGray }
            }
        } else {
            Write-Host "   無効な番号です。" -ForegroundColor Red
        }
    }
}

# ---- 9) スマホ検索を開始 ----
function Start-PhoneSearch {
    $srvDir = Join-Path $env:USERPROFILE 'NaomiAI'
    $bat = Join-Path $srvDir 'スマホ検索サーバー.cmd'
    if (-not (Test-Path $bat)) {
        Write-Host ("   スマホ検索サーバーが見つかりません: {0}" -f $bat) -ForegroundColor Red
        Write-Host "   （このPCにサーバー一式が無い可能性があります）" -ForegroundColor DarkGray
        return
    }
    $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254)' }
    $ip = ($ips | Where-Object { $_.InterfaceAlias -match 'Wi-Fi|Wireless|WLAN' } | Select-Object -First 1 -ExpandProperty IPAddress)
    if (-not $ip) { $ip = ($ips | Select-Object -First 1 -ExpandProperty IPAddress) }
    Write-Host ""
    Write-Host "   スマホ検索サーバーを起動します（別の黒い窓が開きます）。" -ForegroundColor Cyan
    Write-Host "   ※ その窓は開けたままにしてください（閉じると止まります）。" -ForegroundColor DarkGray
    if ($ip) {
        Write-Host ""
        Write-Host "   == iPhoneで開くURL（PCと同じWi-Fiで）==" -ForegroundColor Green
        Write-Host ("       http://{0}:8000" -f $ip) -ForegroundColor Green
        Write-Host "   合言葉は passcode.txt に設定した言葉です。" -ForegroundColor DarkGray
    } else {
        Write-Host "   （IPが取得できませんでした。サーバー窓に表示されるURLを見てください）" -ForegroundColor Yellow
    }
    Start-Process -FilePath $bat | Out-Null
}

# ---- 8) 予定を追加（Googleカレンダーを予定入りで開く。API不要） ----
function Get-JpTime([string]$s) {
    if (-not $s) { return $null }
    $pm = ($s -match '午後|ごご|夕方|夜'); $am = ($s -match '午前|ごぜん|朝')
    $h = $null; $m = 0
    if     ($s -match '(\d{1,2})\s*[:：]\s*(\d{1,2})')   { $h=[int]$matches[1]; $m=[int]$matches[2] }
    elseif ($s -match '(\d{1,2})\s*時\s*半')             { $h=[int]$matches[1]; $m=30 }
    elseif ($s -match '(\d{1,2})\s*時\s*(\d{1,2})\s*分') { $h=[int]$matches[1]; $m=[int]$matches[2] }
    elseif ($s -match '(\d{1,2})\s*時')                  { $h=[int]$matches[1]; $m=0 }
    else { return $null }
    if ($pm -and $h -lt 12) { $h += 12 }
    if ($am -and $h -eq 12) { $h = 0 }
    if ($h -ge 24) { $h = $h % 24 }
    if ($m -ge 60) { $m = 0 }
    return @{ h = $h; m = $m }
}
function Add-CalendarEvent {
    Write-Host ""
    Write-Host "   予定を文章で入力してください。"
    Write-Host "   例）明日15時 徳重さんと打ち合わせ ／ 7/20 10:00-11:30 展示会準備 ／ 来週月曜 終日 出張" -ForegroundColor DarkGray
    Write-Host "   ※ 音声で入れたいときは、入力欄で [Windowsキー]+[H] を押すと話して入力できます。" -ForegroundColor DarkGray
    $text = Read-Host "   予定"
    if ([string]::IsNullOrWhiteSpace($text)) { Write-Host "   入力がありませんでした。" -ForegroundColor Gray; return }
    $now = Get-Date; $date = $now.Date; $t = $text
    if     ($t -match '今日|本日')        { $date = $now.Date }
    elseif ($t -match '明後日|あさって')  { $date = $now.Date.AddDays(2) }
    elseif ($t -match '明日|あした|あす') { $date = $now.Date.AddDays(1) }
    elseif ($t -match '(来週)?\s*([月火水木金土日])曜') {
        $wmap = @{ '日'=0; '月'=1; '火'=2; '水'=3; '木'=4; '金'=5; '土'=6 }
        $diff = ($wmap[$matches[2]] - [int]$now.DayOfWeek + 7) % 7
        if ($diff -eq 0) { $diff = 7 }
        if ($matches[1]) {
            $dnm = (1 - [int]$now.DayOfWeek + 7) % 7
            if ($dnm -eq 0) { $dnm = 7 }
            if ($diff -lt $dnm) { $diff += 7 }
        }
        $date = $now.Date.AddDays($diff)
    }
    elseif ($t -match '(\d{1,2})\s*[/／月]\s*(\d{1,2})') {
        try {
            $cand = Get-Date -Year $now.Year -Month ([int]$matches[1]) -Day ([int]$matches[2]) -Hour 0 -Minute 0 -Second 0
            if ($cand.Date -lt $now.Date) { $cand = $cand.AddYears(1) }
            $date = $cand.Date
        } catch { }
    }
    $parts = $t -split 'から|〜|～|~|—|ー|−|-', 2
    $st = Get-JpTime $parts[0]
    $et = if ($parts.Count -gt 1) { Get-JpTime $parts[1] } else { $null }
    if ($et -and $st -and $et.h -lt $st.h -and $st.h -ge 12) { $et.h += 12 }
    $title = $text
    $title = $title -replace '今日|本日|明後日|あさって|明日|あした|あす', ''
    $title = $title -replace '(来週)?\s*[月火水木金土日]曜日?', ''
    $title = $title -replace '(\d{1,2})\s*[/／月]\s*(\d{1,2})\s*日?', ''
    $title = $title -replace '午前|午後|終日', ''
    $title = $title -replace '(\d{1,2})\s*[:：]\s*(\d{1,2})', ''
    $title = $title -replace '(\d{1,2})\s*時(\s*半|\s*\d{1,2}\s*分?)?', ''
    $title = $title -replace 'から|まで|〜|～|~|—|ー|−|-', ' '
    $title = ($title -replace '\s+', ' ').Trim(([char[]]" 　、。・にのでをへと"))
    if ([string]::IsNullOrWhiteSpace($title)) { $title = $text }
    $allday = (-not $st) -or ($text -match '終日')
    if ($allday) {
        $dates = "{0}/{1}" -f $date.ToString('yyyyMMdd'), $date.AddDays(1).ToString('yyyyMMdd')
        $disp  = "{0}（終日）" -f $date.ToString('yyyy/MM/dd')
    } else {
        $start = $date.AddHours($st.h).AddMinutes($st.m)
        $end   = if ($et) { $date.AddHours($et.h).AddMinutes($et.m) } else { $start.AddHours(1) }
        if ($end -le $start) { $end = $start.AddHours(1) }
        $dates = "{0}/{1}" -f $start.ToString('yyyyMMddTHHmmss'), $end.ToString('yyyyMMddTHHmmss')
        $disp  = "{0} {1}-{2}" -f $start.ToString('yyyy/MM/dd'), $start.ToString('HH:mm'), $end.ToString('HH:mm')
    }
    $url = "https://calendar.google.com/calendar/render?action=TEMPLATE" +
           "&text=$([uri]::EscapeDataString($title))&dates=$dates&ctz=Asia/Tokyo" +
           "&details=$([uri]::EscapeDataString('Naomi Launcher で追加'))"
    Write-Host ""
    Write-Host "   この内容で Google カレンダーを開きます（確認して［保存］を押してください）：" -ForegroundColor Cyan
    Write-Host ("      日時 : {0}" -f $disp) -ForegroundColor Green
    Write-Host ("      予定 : {0}" -f $title) -ForegroundColor Green
    Write-Host ""
    if ((Read-Host "   開いてよいですか？ [Y=はい / N=やめる]") -match '^[NnＮｎ]') { Write-Host "   やめました。" -ForegroundColor Gray; return }
    Start-Process $url | Out-Null
    Write-Host "   Google カレンダーを開きました。ブラウザで［保存］を押してください。" -ForegroundColor Gray
}

# ---- 7) 設定 ----
function Set-Config {
    $f = Get-Folders
    $dbPath   = Join-Path $env:LOCALAPPDATA 'NaomiAI\naomi_ai.db'
    $updPath  = Join-Path $f.naomi_ai 'update_naomi_ai.bat'
    $srchPath = Join-Path $f.naomi_ai 'search_naomi_ai.bat'
    $editable = @(
        @{ key='vault';    name='Obsidian Vault'; val=$f.vault },
        @{ key='threads';  name='Threads';        val=$f.threads },
        @{ key='naomi_ai'; name='直美AI';         val=$f.naomi_ai },
        @{ key='note';     name='Note';           val=$f.note })
    Write-Host ""
    Write-Host "   -- 現在の設定（1〜4は変更可） --"
    for ($i = 0; $i -lt $editable.Count; $i++) {
        $v = $editable[$i].val
        $stt = if ($v -and (Test-Path $v)) { 'OK' } elseif ($v) { '見つからない' } else { '未設定' }
        Write-Host ("   {0}) {1,-16} {2}  [{3}]" -f ($i + 1), $editable[$i].name, $v, $stt)
    }
    Write-Host "   ── 参照のみ ──" -ForegroundColor DarkGray
    Write-Host ("      索引データベース : {0}  [{1}]" -f $dbPath,   $(if (Test-Path $dbPath) { 'OK' } else { '未作成' })) -ForegroundColor DarkGray
    Write-Host ("      更新スクリプト   : {0}  [{1}]" -f $updPath,  $(if (Test-Path $updPath) { 'OK' } else { 'なし' })) -ForegroundColor DarkGray
    Write-Host ("      検索スクリプト   : {0}  [{1}]" -f $srchPath, $(if (Test-Path $srchPath) { 'OK' } else { 'なし' })) -ForegroundColor DarkGray
    Write-Host "   0) 戻る"
    $a = Read-Host "   変更する番号を入力（0で戻る）"
    if ($a -eq '0' -or [string]::IsNullOrWhiteSpace($a)) { return }
    $idx = ($a -as [int]) - 1
    if ($null -eq ($a -as [int]) -or $idx -lt 0 -or $idx -ge $editable.Count) { Write-Host "   無効な番号です。" -ForegroundColor Red; return }
    $key = $editable[$idx].key
    $picked = Pick-Folder ($editable[$idx].name + ' のフォルダを選択してください')
    if ($picked) { $script:Overrides[$key] = $picked; Save-Overrides; Write-Host ("   保存しました: {0} = {1}" -f $editable[$idx].name, $picked) -ForegroundColor Green }
    else { Write-Host "   選択がキャンセルされました（変更なし）。" -ForegroundColor Gray }
}

# ---- 前回更新後の変更（最新ログから軽く取得。無ければ $null） ----
function Get-LastUpdateChanges {
    try {
        $logdir = Join-Path $env:LOCALAPPDATA 'NaomiAI\logs'
        if (-not (Test-Path $logdir)) { return $null }
        $latest = Get-ChildItem $logdir -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $latest) { return $null }
        $c = Get-Content $latest.FullName -Raw -Encoding UTF8
        $add = 0; $chg = 0; $miss = 0; $found = $false
        foreach ($m in [regex]::Matches($c, '追加\s*(\d+).*?変更\s*(\d+).*?消失\s*(\d+)')) {
            $add += [int]$m.Groups[1].Value; $chg += [int]$m.Groups[2].Value; $miss += [int]$m.Groups[3].Value; $found = $true
        }
        if ($found) { return @{ add = $add; chg = $chg; miss = $miss } }
        return $null
    } catch { return $null }
}

# ---- 朝のダッシュボード（軽い確認のみ・全走査しない・推測しない） ----
function Show-Dashboard {
    $f = Get-Folders
    Write-Host ""
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host " おはようございます　直美さん" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ("  " + (Get-Date).ToString('yyyy年M月d日'))
    Write-Host ""
    Write-Host "  【データ状況】"
    $gd = $script:GDrive
    Write-Host ("    Google Drive : " + $(if ($gd) { '利用可能' } else { '未接続' })) -ForegroundColor $(if ($gd) { 'Gray' } else { 'Yellow' })
    $odok = ($env:OneDrive -and (Test-Path $env:OneDrive))
    Write-Host ("    OneDrive     : " + $(if ($odok) { '利用可能' } else { '未接続' })) -ForegroundColor $(if ($odok) { 'Gray' } else { 'Yellow' })
    $dbok = (Test-Path (Join-Path $env:APPDATA 'Dropbox\info.json')) -or (Test-Path (Join-Path $env:LOCALAPPDATA 'Dropbox\info.json')) -or (Test-Path (Join-Path $env:USERPROFILE 'Dropbox'))
    Write-Host ("    Dropbox      : " + $(if ($dbok) { '利用可能' } else { '未接続' })) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  【前回更新後の変更】"
    $chg = Get-LastUpdateChanges
    if ($chg) { Write-Host ("    新規 {0} / 更新 {1} / 消失 {2}" -f $chg.add, $chg.chg, $chg.miss) }
    else { Write-Host "    確認できませんでした（6)索引を更新 で最新に）" -ForegroundColor DarkGray }
    Write-Host ""
    Write-Host "  【今日の仕事】"
    $td = if ($f.vault) { Join-Path $f.vault 'Threads\05_投稿下書き' } else { $null }
    if ($td -and (Test-Path $td)) {
        $n = @(Get-ChildItem $td -Recurse -Filter *.md -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^_|README' }).Count
        Write-Host ("    Threads下書き : {0} 件" -f $n)
    } else { Write-Host "    Threads下書き : 確認できませんでした" -ForegroundColor DarkGray }
    if ($f.note -and (Test-Path $f.note)) {
        $n = @(Get-ChildItem $f.note -Recurse -Filter *.md -ErrorAction SilentlyContinue).Count
        Write-Host ("    Note下書き    : {0} 件" -f $n)
    } else { Write-Host "    Note下書き    : 確認できませんでした（未設定）" -ForegroundColor DarkGray }
    $img = '確認できませんでした'; $kobe = '確認できませんでした'
    try {
        $helper = Join-Path $PSScriptRoot 'dashboard_data.py'
        if ((Get-Command python -ErrorAction SilentlyContinue) -and (Test-Path $helper)) {
            $env:PYTHONUTF8 = '1'
            foreach ($line in (& python $helper 2>$null)) {
                if ($line -match '^IMG=(-?\d+)') { if ([int]$matches[1] -ge 0) { $img = "$($matches[1]) 件" } }
                if ($line -match '^KOBE=(-?\d+)\|(.*)$') { if ([int]$matches[1] -ge 0) { $kobe = "$($matches[1]) 件" + $(if ($matches[2]) { "（最新 $($matches[2])）" } else { '' }) } }
            }
        }
    } catch { }
    Write-Host ("    昨日更新の画像 : {0}" -f $img)
    Write-Host ("    神戸大学の資料 : {0}" -f $kobe)
    Write-Host "    メール未返信   : 未連携" -ForegroundColor DarkGray
}

# =====================================================================
#  メニュー・ループ
# =====================================================================
Show-Dashboard

while ($true) {
    Write-Host ""
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "        Naomi Launcher"          -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) 今日の仕事（WORKLOG）"
    Write-Host "  2) Threads"
    Write-Host "  3) 直美AI"
    Write-Host "  4) Note"
    Write-Host "  5) ファイル検索"
    Write-Host "  6) 直美AIの索引を更新"
    Write-Host "  7) 設定"
    Write-Host "  8) 予定を追加（カレンダー）"
    Write-Host "  9) スマホ検索を開始"
    Write-Host "  0) 終了"
    Write-Host ""
    $sel = Read-Host "  番号を入力してください"

    if ($sel -eq '0' -or $sel -eq 'q') { Write-Host "   終了します。" -ForegroundColor Gray; break }

    try {
        $f = Get-Folders
        switch ($sel) {
            '1' { Open-TodaysWork }
            '2' { Start-ClaudeIn $f.threads 'Threads' }
            '3' { Start-ClaudeIn $f.naomi_ai '直美AI' }
            '4' {
                if ($f.note -and (Test-Path $f.note)) { Start-ClaudeIn $f.note 'Note' }
                else { Write-Host "   Note用フォルダが設定されていません。" -ForegroundColor Yellow; Write-Host "   （7)設定 で指定できます）" -ForegroundColor DarkGray }
            }
            '5' { Run-Search $f.naomi_ai }
            '6' { Update-Index $f.naomi_ai }
            '7' { Set-Config }
            '8' { Add-CalendarEvent }
            '9' { Start-PhoneSearch }
            default { Write-Host "   無効な番号です。" -ForegroundColor Red }
        }
    } catch {
        Write-Host ("   エラーが発生しました: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }

    Write-Host ""
    [void](Read-Host "   Enterキーでメニューに戻ります")
}
