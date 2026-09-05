# Grok 固有の補足

共通ルール（日本語、Git、Nix、検証、サブエージェントの委譲）は `~/.claude/CLAUDE.md`。ここには差分だけ。Claude のモデル名は使わない。

## サブエージェント

- 調査: `spawn_subagent` / `explore`（編集しない。深さは prompt に `quick` / `medium` / `very thorough`）
- 計画: `plan`（編集しない）
- 実装: `general-purpose`
- 子はトップレベルのみ。独立なら `background: true`、回収は `get_command_or_subagent_output`
- 並列でファイルを書くときは `isolation: worktree`。同じファイルを2体に触らせない
- `model` はユーザー指定時のみ。explore の既定は `config.toml` の `[subagents.models]`

## /pr

確認ダイアログは出ない。フラグ無しの commit / push / PR作成は `pr-mode.sh` の PreToolUse が deny する。force push は `/pr` 中でも deny。自動許可対象外の git 書き込みは hook の ask（always-approve でも確認になる）。

## 破壊的操作

`guard-destructive.sh` の deny は止まる。ask は always-approve でも確認プロンプトになる。許可ルートは `.claude/dev-roots`（共通ルールは `~/.claude/CLAUDE.md`）。
