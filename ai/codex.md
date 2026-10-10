# Codex 固有の補足

設定は `~/.codex/config.toml`（モデル・承認ポリシー・サンドボックス）と `~/.codex/hooks.json`（フック）。実体は dotfiles の `codex/`。Claude Code / Grok の `settings.json`・`pr-mode.sh`・`guard-destructive.sh` は動かない。

- `hooks.json` の PreToolUse は**拒否専用**。`/pr` プロンプトを起動していないターンの commit / push / PR の作成と更新は拒否される。`/pr` 中も自動承認はされないので Codex の承認ダイアログに従う
- force push・デフォルトブランチへの push・`gh pr merge`・`sudo`・`--amend` / `--no-verify` は `/pr` 中でも拒否される
- サブエージェントから commit / push / PR 操作をしない
- モデルと reasoning effort はユーザーが `config.toml` で決める（`--model` で勝手に変えない）
