# Codex 固有の補足

設定は `~/.codex/config.toml`、フックは `~/.codex/hooks.json`（dotfiles の `codex/` の宣言を home-manager がマージした実ファイル。trust・信頼ハッシュはホーム側だけに残る）。Claude/Grokの設定は読み込まず、共通の事故防止判定・検証ゲートを使う。

- `/pr` 起動は文中の `$pr`、依頼の先頭語の `/pr`・旧 `/prompts:pr`。`~/.codex/skills/pr/SKILL.md` に従う
- PreToolUseは拒否専用。共通指示のGit制限・危険操作の禁止をフックでも強制する。確認対象は常に拒否し、ユーザーに手動実行を依頼する
- フックの確認要求や拒否を、別の書き方やツールで迂回しない
- フックの追加・変更後はユーザーが `/hooks` で確認し信頼する。エージェントは信頼状態を書き換えない
- サブエージェントから commit / push / PR 操作をしない
- モデルと reasoning effort はユーザーが `config.toml` で決める（dotfiles の `codex/config.toml`。`--model` で変えない）
