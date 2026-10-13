---
name: codex
description: Claude Code のセッションから Codex CLI を非対話（codex exec）で起動して作業を任せ、結果をレビューする。「Codexに作業させて」「Codexを起動して」「Codexに任せて」などユーザーが Codex を明示的に求めた依頼や /codex 実行時に使用。Claude Code 専用（OpenCode・Grok など他CLIでは使わない）。
allowed-tools:
  - Bash(bash ~/.claude/skills/codex/scripts/run.sh:*)
---

# Codex に作業を任せる

> **Claude Code 専用。** OpenCode・Grok など他の CLI で読み込んだ場合は使わない。

Codex をサブエージェント代わりに使う。目的は Claude のトークン節約なので、手順は軽く回す。使うのはユーザーが Codex を求めた作業だけで、それ以外は従来どおりサブエージェントへ回す。

## 役割分担

- **Claude**：要件整理・計画・設計・タスク分解・指示・レビュー・最終判断
- **Codex**：それ以外（実装・テスト作成・調査・ドキュメント更新など）。設計判断は渡さない

## モデル

既定は GPT-6.1 Sol の medium（`--model gpt-6.1-sol --effort medium`、スクリプトの既定値）。ユーザーが指定したときだけ `--model` / `--effort` で変える。

## 手順

1. Claude が計画を立て、Codex 向けの自己完結した指示を書く（Codex は会話を知らない）。含めるもの：対象ファイル・方針・制約・完了条件・検証コマンド。最後に次を添える：
   > 日本語で「変更ファイル／実行した検証と結果／未解決点」の形で簡潔に報告すること。git commit / push / PR 作成・グローバルなインストールはしないこと。
2. 実行する。長くなりうるので Bash は `run_in_background: true` を既定にする。

   ```bash
   bash ~/.claude/skills/codex/scripts/run.sh --dir /abs/path/to/project <<'EOF'
   ...指示...
   EOF
   ```

   独立した作業が複数あっても、同じ作業ツリーでは1本ずつ流す。
3. 要約（最終回答・失敗したコマンド・エラー）を読み、Claude が `git diff` で変更をレビューして検証コマンドを通す。直しは小さければ Claude が直接、まとまった量なら `--session <ID>` で Codex に追加の指示を出す。
4. ユーザーに報告する：使ったモデル・変更ファイル・検証結果・未解決点。

トークン節約のため、独立レビュー用のサブエージェントは既定では起動せず、Claude のレビューで済ませる。セキュリティ境界や広範囲の挙動変更など、見落としのコストが高いときだけ起動する。

## 注意

- サンドボックスは workspace-write 固定（作業ディレクトリの外へは書かない）。承認・サンドボックスを外すオプションは使わない。
- Codex 側の安全装置は `~/.codex/hooks.json` の `guard.sh`（`/pr` 外のコミット・push・PR 作成、force push、`sudo` を拒否）と `~/.codex/AGENTS.md`。Claude Code のフックは Codex の中では効かない。作業ディレクトリ内のファイル削除は止まらないので、消してほしくないものは指示に書く。
- Codex は `CLAUDE.md` を読まず `AGENTS.md` を読むので、`CLAUDE.md` にしかない制約は指示に書く。
- Codex の実行中は、同じファイルを Claude が編集しない。
