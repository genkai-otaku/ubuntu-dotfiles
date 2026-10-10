# Devin 固有の補足

設定は `~/.config/devin/config.json`（モデル・`permissions`）。実体は dotfiles の `devin/config.json`。Claude Code / Grok の `settings.json`・Hooks は動かない。

- `permissions` の `ask` に落ちた操作はユーザーの承認を得てから実行する。`deny`（`sudo`・force push・`gh pr merge`）は迂回しない。プロジェクト側で緩める `.devin/config.json` を勝手に作らない
- `/pr` に相当する明示指示がないターンでは commit / push / PR 操作をしない（成果物は未コミットで残して報告する）
- Devin のクラウド側セッションへ、このマシンの秘密情報や `~/.config` の認証ファイルを送らない
