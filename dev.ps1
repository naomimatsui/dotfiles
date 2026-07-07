# =====================================================================
#  dev.ps1  —  Claude Code プロジェクトランチャー
#  使い方: PowerShell で  dev  と入力
# =====================================================================

# 日本語表示のため出力を UTF-8 に
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = Join-Path $env:USERPROFILE 'GitHub'

# フォルダ名 -> 表示名 のマッピング（増えたらここに追記）
$DisplayNames = @{
    'marinecore'  = 'MARINE CORE'
    'akari'       = 'AKARI'
    'byou-awase'  = '秒合わせ'
    'budget-cago' = '予算カゴ'
    'HomeAI'      = 'HomeAI'
    'butudan-app' = '仏壇アプリ'
}

function Get-Disp($name) {
    if ($DisplayNames.ContainsKey($name)) { return $DisplayNames[$name] }
    return $name
}

# .git を持つフォルダを自動一覧化（dotfiles は開発対象外なので除外）
$projects = Get-ChildItem -Path $Root -Directory -ErrorAction SilentlyContinue |
    Where-Object { (Test-Path (Join-Path $_.FullName '.git')) -and $_.Name -ne 'dotfiles' } |
    Sort-Object Name

if (-not $projects -or $projects.Count -eq 0) {
    Write-Host "`nプロジェクトが見つかりません: $Root" -ForegroundColor Yellow
    return
}

# ---- プロジェクト一覧 ----
Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "   Claude Code  プロジェクト選択" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""
for ($i = 0; $i -lt $projects.Count; $i++) {
    Write-Host ("   {0})  {1}" -f ($i + 1), (Get-Disp $projects[$i].Name))
}
Write-Host ""

$sel = Read-Host "   番号を入力 (q=中止)"
if ($sel -eq 'q' -or [string]::IsNullOrWhiteSpace($sel)) { return }
$idx = ($sel -as [int]) - 1
if ($null -eq ($sel -as [int]) -or $idx -lt 0 -or $idx -ge $projects.Count) {
    Write-Host "   無効な番号です。" -ForegroundColor Red
    return
}

$proj = $projects[$idx]
$disp = Get-Disp $proj.Name
Set-Location $proj.FullName

# ---- git status ----
Write-Host ""
Write-Host "===================================" -ForegroundColor Green
Write-Host ("   {0}   git status" -f $disp) -ForegroundColor Green
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
Write-Host ("   未Push     : {0} commit(s) ahead" -f $ahead) -ForegroundColor $(if ($ahead -gt 0) { 'Yellow' } else { 'Gray' })
if ($behind -gt 0) {
    Write-Host ("   同期状態   : {0} commit(s) 遅れ（pull推奨）" -f $behind) -ForegroundColor Yellow
} else {
    Write-Host "   同期状態   : 最新" -ForegroundColor Gray
}

# ---- git pull 確認（毎回確認・自動では引かない） ----
Write-Host ""
$ans = Read-Host "   最新を取得しますか？ [Y/N]"
if ($ans -match '^[Yy]') {
    git pull --ff-only
}

# ---- TODO / README 表示 ----
$todoFile = $null
foreach ($f in @('TODO.md', 'README.md')) {
    $p = Join-Path $proj.FullName $f
    if (Test-Path $p) { $todoFile = $p; break }
}
Write-Host ""
Write-Host "===================================" -ForegroundColor Magenta
Write-Host ("   {0}   今日やること" -f $disp) -ForegroundColor Magenta
Write-Host "===================================" -ForegroundColor Magenta
if ($todoFile) {
    Get-Content -Path $todoFile -Encoding UTF8 | ForEach-Object { Write-Host "   $_" }
} else {
    Write-Host "   TODO.md / README.md は未設定です。" -ForegroundColor DarkGray
    Write-Host "   （templates\TODO.md を各プロジェクトに置くと表示されます）" -ForegroundColor DarkGray
}
Write-Host ""

# ---- Claude Code 起動 ----
Write-Host "   Claude Code を起動します..." -ForegroundColor Cyan
Write-Host ""
claude
