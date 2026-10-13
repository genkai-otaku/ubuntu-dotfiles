---
name: opencode
description: Claude Code のセッションから OpenCode を非対話で起動して作業を任せ、結果をレビューする。「OpenCodeに作業させて」「OpenCodeを起動して」「OpenCodeに任せて」などユーザーが OpenCode を明示的に求めた依頼や /opencode 実行時に使用。Claude Code 専用（OpenCode・Grok など他CLIでは使わない）。
allowed-tools:
  - Bash(bash ~/.claude/skills/opencode/scripts/run.sh:*)
---

# OpenCode に作業を任せる

> **Claude Code 専用。** OpenCode・Grok など他の CLI で読み込んだ場合は使わない（入れ子起動になる）。

OpenCode をサブエージェント代わりに使う。目的は Claude のトークン節約なので、手順は軽く回す。使うのはユーザーが OpenCode を求めた作業だけで、それ以外は従来どおりサブエージェントへ回す。

## 役割分担

- **Claude**：要件整理・計画・設計・タスク分解・指示・レビュー・最終判断
- **OpenCode**：それ以外（実装・テスト作成・調査・ドキュメント更新など）。設計判断は渡さない

## モデル

既定は Claude Haiku 5.5 medium（`opencode-go/claude-haiku-5-5#medium`、スクリプトの既定値）。ユーザーが指定したときだけ `--model provider/model#variant` で変える。

## 手順

1. Claude が計画を立て、OpenCode 向けの自己完結した指示を書く（OpenCode は会話を知らない）。含めるもの：対象ファイル・方針・制約・完了条件・検証コマンド。最後に次を添える：
   > 日本語で「変更ファイル／実行した検証と結果／未解決点」の形で簡潔に報告すること。git commit / push / PR 作成・削除・グローバルなインストールはしないこと。
2. 実行する。長くなりうるので Bash は `run_in_background: true` を既定にする。

   ```bash
   bash ~/.claude/skills/opencode/scripts/run.sh --dir /abs/path/to/project <<'EOF'
   ...指示...
   EOF
   ```

   独立した作業が複数あっても、同じ作業ツリーでは1本ずつ流す（並行すると同じファイルを取り合う）。
3. 要約（最終回答・拒否された権限・失敗したツール）を読み、Claude が `git diff` で変更をレビューして検証コマンドを通す。直しは小さければ Claude が直接、まとまった量なら `--session <ID>` で OpenCode に追加の指示を出す。
4. ユーザーに報告する：使ったモデル・変更ファイル・検証結果・未解決点（拒否された操作を含む）。

トークン節約のため、独立レビュー用のサブエージェントは既定では起動せず、Claude のレビューで済ませる。セキュリティ境界や広範囲の挙動変更など、見落としのコストが高いときだけ起動する。

## 注意

- `--auto` は付けない（ask 規則の rm・git commit・git push 等が自動承認される）。付けなければ ask の操作は自動拒否されるので、必要なら Claude が自分のルールで行う。
- Claude Code のフックは OpenCode の中では効かない。OpenCode は `CLAUDE.md` を読まず `AGENTS.md` を読むので、`CLAUDE.md` にしかない制約は指示に書く。
- OpenCode の実行中は、同じファイルを Claude が編集しない。
