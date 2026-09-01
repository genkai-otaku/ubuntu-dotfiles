# Codex 固有の補足

共通ルール（日本語、Git、Nix、パッケージ）は `~/.claude/CLAUDE.md` に従う。
SessionStart フックが同ファイルを読み込む。フックが未信頼のときは自分でそのファイルを読むこと。
ここには Codex だけの差分だけ書く。

`~/.claude/CLAUDE.md` の「モデル運用ポリシー」は Claude Code 専用（Fable 5 / Sonnet / Opus、`model: "sonnet"` 等）。Codex ではこのファイルに従い、Claude のモデル名は指定しない。

## 役割

- メイン: 分解、委譲、監査、最終判断
- 調査: `explorer`（編集しない）
- 実装: `worker`
- 汎用: `default`
- 自明で局所的な修正、設計と実装が不可分な高難度はメインがやってよい
- 独立した調査・実装・検証が複数あるときだけ委譲する

## 起動ルール

- 子はトップレベルからのみ。ネスト禁止
- 独立タスクは並列で spawn し、全部待ってからまとめる。スレッドの確認は `/agent`
- 調査: `explorer`（read-only）
- ファイルを書く実装が並列: 所有範囲を分け、同じファイルを2体に触らせない。終わったら親が取り込む
- 子への指示は自己完結: 対象パス、やってはいけないこと、完了条件（実行するテストコマンド）、返す形式
- 成果物はメインがレビューしてから完了

## モデル

- 呼び出し時のモデル指定はユーザーが明示したときだけ。未指定なら親を継承する
- 既定は `~/.codex/config.toml` の `agents.default_subagent_model`、または `~/.codex/agents/*.toml` の `model`
- `sonnet` / `opus` / `haiku` / `fable` は指定しない

## /pr

- git commit / push / PR 作成は、ユーザー入力の先頭が `/pr` または `$pr` のときだけ許可（CLAUDE.md と同じ）
- 「PRを出して」などの自然言語では起動しない。`/pr` と打つよう案内する
- `claude-pr-mode-*` フラグを自分で作ってはならない
- Codex では `approval_policy = "never"` のため確認は出ない。`pr-mode.sh` が `/pr` 中だけ通し、それ以外は PreToolUse で deny する。`/pr` 中はコマンドをそのまま実行する
