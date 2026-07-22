# グローバル共通ルール（全プロジェクト共通）

このファイルは全PC・全プロジェクトで共通の Claude Code への指示です。
`~/.claude/CLAUDE.md` に反映して使います。

## 環境ルール
- コードは必ず `C:\Users\<user>\GitHub\<project>`（Mac は `~/GitHub/<project>`）で管理する。
- **Obsidian Vault 内では絶対に Git 管理しない。**
- Obsidian Vault はアイデア・営業資料・メモ専用。
- 🛑 **Vault の正パスは `%USERPROFILE%\ObsidianVault`（Mac は `~/ObsidianVault`）＝Obsidian Sync のローカル。**
  次の3つは **2026-07-18 に凍結したコピー。絶対に開かない・編集しない**（開いても他の端末に届かない）：
  - `G:\マイドライブ\Obsidian Vault`
  - `C:\Obsidian Vault`
  - `%USERPROFILE%\OneDrive\デスクトップ\Obsidian Vault`

  いずれも `CLAUDE.md` の冒頭が「🛑 STOP」で始まる道しるべに差し替え済み。
  **これを見たら、そこでは作業せず正パスに切り替えること。**

## 作業フロー
1. `dev` でプロジェクト選択
2. git status 確認 → 必要なら pull
3. 作業
4. `git add` → `git commit` → `git push`

## コミットメッセージ
- 日本語または英語、変更内容が一目で分かる粒度で。

## 家・会社で同一環境を保つ
- 新PCは `git clone dotfiles` → `install.ps1` → `dev` で再現する。
