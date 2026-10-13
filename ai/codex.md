# Codex 固有の補足

設定は `~/.codex/config.toml`（モデル・承認ポリシー・サンドボックス）と `~/.codex/hooks.json`（フック）。実体は dotfiles の `codex/`。Claude Code / Grok の `settings.json` とフック登録は読み込まれない。Codex用アダプターから共通の事故防止判定・検証ゲートを利用する。

- Codex専用スキルは `~/.codex/skills`。`$readme`・`$nix-setup`・`$git-pull`・`$clean-branches` がClaude Codeと共通の手順を使う。Claudeのモデル名・`allowed-tools`・Agent設定はCodexへ適用しない
- この環境の `/pr` 明示起動はCodexでは `$pr`・`/pr`・旧 `/prompts:pr` を含む。`~/.codex/skills/pr/SKILL.md` を読み、自然言語のPR依頼だけでは実行しない
- `hooks.json` の PreToolUse は**拒否専用**。明示起動していないターンの commit / push / PR の作成と更新は拒否される。`/pr` 中も自動承認はされないので Codex の承認ダイアログに従う
- force push・デフォルトブランチへの push・`gh pr merge`・`sudo`・`--amend` / `--no-verify` は `/pr` 中でも拒否される
- フックが確認を求める操作は、案内に従う。承認情報が届く環境では理由を添えて `require_escalated` で再試行する。CLI 0.162.1ではフックへ承認情報が届かないため、対象コマンドと理由を示してユーザーに手動実行を依頼する。拒否された操作は実行を止め、別の書き方やツールで迂回しない
- `hooks.json` の追加・変更後は `/hooks` で内容を確認して信頼する。信頼はユーザーが行い、エージェントが信頼状態を書き換えない
- サブエージェントから commit / push / PR 操作をしない
- モデルと reasoning effort はユーザーが `config.toml` で決める（`--model` で勝手に変えない）
