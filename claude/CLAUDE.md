# グローバル共通ルール（全プロジェクト共通）

このファイルは全PC・全プロジェクトで共通の Claude Code への指示です。
`~/.claude/CLAUDE.md` に反映して使います。

## 環境ルール
- コードは必ず `C:\Users\<user>\GitHub\<project>` で管理する。
- **Google Drive（Obsidian Vault）内では絶対に Git 管理しない。**
- Obsidian Vault（`G:\マイドライブ\Obsidian Vault`）はアイデア・営業資料・メモ専用。

## 作業フロー
1. `dev` でプロジェクト選択
2. git status 確認 → 必要なら pull
3. 作業
4. `git add` → `git commit` → `git push`

## コミットメッセージ
- 日本語または英語、変更内容が一目で分かる粒度で。

## 家・会社で同一環境を保つ
- 新PCは `git clone dotfiles` → `install.ps1` → `dev` で再現する。
