# Grok 固有の補足

共通ルール（日本語、Git、Nix、パッケージ）は `~/.claude/CLAUDE.md` に従う。
ここには Grok だけの差分だけ書く。

`~/.claude/CLAUDE.md` の「モデル運用ポリシー」は Claude Code 専用（Fable 5 / Sonnet / Opus、`model: "sonnet"` 等）。Grok ではこのファイルに従い、Claude のモデル名は指定しない。

## 役割

- メイン: 分解、委譲、監査、最終判断
- 調査: `spawn_subagent` / `subagent_type: explore`（編集しない）
- 計画: `plan`（編集しない。Critical Files を列挙して返せ）
- 実装: `general-purpose`
- ツール名は一覧の `spawn_subagent`（環境によっては `task`）
- 自明で局所的な修正、設計と実装が不可分な高難度はメインがやってよい
- 独立した調査・実装・検証が複数あるときだけ委譲する

## 起動ルール

- 子はトップレベルからのみ。ネスト禁止
- 独立タスクは `background: true` で並列。回収は `get_command_or_subagent_output`。監視は `Ctrl+G`
- 依存する作業は待ってから次を立てる（`background: false`）。段階継続は `resume_from`（完了済み・同一タイプのみ）
- 調査・計画: `isolation: none`
- ファイルを書く実装が並列: `isolation: worktree`。所有ディレクトリを分け、同じファイルを2体に触らせない。終わったら親が取り込む
- 子への prompt は自己完結: 対象パス、やってはいけないこと、完了条件（実行するテストコマンド）、返す形式
- 調査の深さは prompt に `quick` / `medium` / `very thorough` で書く（explore 定義がこの3語を見る。ツール引数ではない）
- 成果物はメインがレビューしてから完了

## モデル

- 呼び出し時の `model` はユーザーが明示したときだけ付ける。未指定なら親を継承する
- タイプ単位の既定は `~/.grok/config.toml` の `[subagents.models].<type>`、または `~/.grok/agents/*.md` の frontmatter `model:`
- 使える ID は `grok models` で確認する。explore は `config.toml` の `[subagents.models]` で `grok-4.5` へ振ってある
- `sonnet` / `opus` / `haiku` / `fable` は指定しない

## /pr

- git commit / push / PR 作成は、ユーザー入力の先頭が `/pr` のときだけ許可（CLAUDE.md と同じ）
- 「PRを出して」などの自然言語では起動しない。`/pr` と打つよう案内する
- `claude-pr-mode-*` フラグを自分で作ってはならない
- Grok では確認は出ない。`pr-mode.sh` が `/pr` 中だけ通し、それ以外は PreToolUse で deny する。`/pr` 中はコマンドをそのまま実行する
