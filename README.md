# dotfiles — Claude Code 開発環境（家・会社・新PC 共通）

家・会社・将来の新しいPCでも、**10分以内で全く同じ Claude Code 開発環境**を再現するための設定一式。

## コンセプト
| 用途 | 保存場所 | 同期 | Git |
|---|---|---|---|
| アイデア・営業資料・メモ（Obsidian） | `%USERPROFILE%\ObsidianVault` | Obsidian Sync | ❌ しない |
| コード（アプリ開発） | `C:\Users\<user>\GitHub` | GitHub | ✅ する |

> **絶対ルール:** Google Drive 内では Git 管理しない。コードは必ず `GitHub` フォルダで管理する。

## 収録物
| ファイル | 役割 |
|---|---|
| `dev.ps1` | Claude Code プロジェクトランチャー（`dev` コマンド本体） |
| `Microsoft.PowerShell_profile.ps1` | PowerShell Profile マスター（`dev` 関数など） |
| `install.ps1` | 新PCセットアップ（Profile反映・リポjson clone・git config） |
| `claude/settings.json` | Claude Code 共通設定 |
| `claude/CLAUDE.md` | 全プロジェクト共通のグローバル指示 |
| `templates/TODO.md` | 各プロジェクトに置く TODO 雛形 |

## `dev` の動作（dev 2.0）

Obsidian を普段使いの中心にしつつ、**アプリ開発をした日だけ GitHub 同期**できるランチャー。

```
dev
 ↓ プロジェクト一覧を表示
    1) Obsidian Vault   [git無]
    2) AKARI
    3) HomeAI           [企画 / git無]
    4) 秒合わせ
    5) 予算カゴ
    6) MARINE CORE
 ↓ 番号を入力
```

### Obsidian Vault を選んだ場合（git操作なし）
```
 → %USERPROFILE%\ObsidianVault へ移動
 → 重要ファイル確認（🏠 HOME.md / PROJECTS.md / TODAY.md / _system\INDEX.md を ✓/✗ 表示）
 → Claude Code 起動
 → 終了後も git 操作なし（Google Drive 同期に任せる）
```

### GitHubプロジェクトを選んだ場合
```
 → 対象フォルダへ移動
 → git status 表示（Branch / 未コミット / 未Push / 同期状態）
 → git fetch でリモート差分を確認
 → 【更新がある時だけ】「最新を取得しますか？ [Y/N]」→ Y なら git pull --ff-only
 → README.md / TODO.md / CHANGELOG.md があれば表示
 → Claude Code 起動
 ─ 終了後 ─
 → git status を再確認
 → 【変更がある時だけ】「GitHubへ保存しますか？ [Y/N]」
     → Y なら: git add -A → コミットメッセージ入力 → git commit → git push
     → 変更が無ければ何もしない
```

- **HomeAI** は現状 GitHub リポ未作成のため、選ぶと企画フォルダ `App Ideas/HomeAI Project/`（Google Drive内）を git操作なしで開く。リポができたら自動で git 扱いに移行。
- GitHub リポが増えても自動で一覧化される。並び順・表示名は `dev.ps1` の `$layout` / `$DisplayNames` で管理。
- Claude 起動は **PATH → Windows Store版 → 通常版** の順で自動解決（家PC・会社PC / Store版・通常版の両対応）。

## 新しいPCでのセットアップ（3ステップ）
```powershell
# 1) dotfiles を clone
git clone https://github.com/naomimatsui/dotfiles.git "$env:USERPROFILE\GitHub\dotfiles"

# 2) セットアップ実行（Profile反映・主要リポ clone・git config）
& "$env:USERPROFILE\GitHub\dotfiles\install.ps1"

# 3) 新しい PowerShell を開いて
dev
```

## 各プロジェクトに TODO を置く
`templates\TODO.md` をコピーして各リポジトリ直下に `TODO.md` として置くと、`dev` 起動時に表示される。

## 起動方法（お好みで）
- **`dev` と入力**（最速・推奨）
- デスクトップ / タスクバー ショートカット（リンク先: `powershell.exe -NoExit -Command "dev"`)
- Windows Terminal プロファイル

## 将来追加予定
- [ ] fzf あいまい検索
- [ ] 最近使ったプロジェクト / お気に入り
- [ ] GitHub 通知 / Issues / PR 表示
- [ ] GitHub Pages URL 表示
- [ ] `npm run dev` / localhost 自動起動 / ブラウザ自動起動

---

## 家PC・会社PCでの使い方
家でも会社でも操作は完全に同じ。コードは常に `C:\Users\<user>\GitHub` 配下で扱う。

### 毎日の開始手順
1. 新しい PowerShell / Windows Terminal を開く
2. `dev` と入力
3. プロジェクトを番号で選択
4. `git status` を確認
5. 「最新を取得しますか？ [Y/N]」→ **基本は Y**（他PCの変更を取り込む）
6. TODO を確認 → Claude Code 起動 → 作業開始

### 毎日の終了手順
1. `git status` で変更確認
2. `git add -A`
3. `git commit -m "作業内容"`
4. `git push` （他PCに反映される）

> 「開始で pull・終了で push」を徹底すれば、家と会社で常に同じ状態を保てる。

## 新しいPCでの再現手順
```powershell
# 1) dotfiles を clone
git clone https://github.com/naomimatsui/dotfiles.git "$env:USERPROFILE\GitHub\dotfiles"

# 2) セットアップ（PATH登録・主要リポ clone・git config）
& "$env:USERPROFILE\GitHub\dotfiles\install.ps1"

# 3) 新しい PowerShell を開いて
dev
```

## PowerShell 実行ポリシーが必要な場合
`dev.ps1` がブロックされる場合、**CurrentUser のみ** `RemoteSigned` にする（管理者不要・システム全体は変更しない）:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```
確認:
```powershell
Get-ExecutionPolicy -List   # CurrentUser が RemoteSigned ならOK
```

## 保存場所のルール（重要）
| 用途 | 場所 | 同期 | Git |
|---|---|---|---|
| Obsidian（アイデア・営業資料・メモ） | `%USERPROFILE%\ObsidianVault` | Obsidian Sync | ❌ しない |
| コード（アプリ開発） | `C:\Users\<user>\GitHub` | GitHub | ✅ する |

- **Google Drive は Obsidian 専用。GitHub はコード専用。**
- Google Drive 内では絶対に Git 管理しない（同期競合で `.git` 破損の恐れ）。
