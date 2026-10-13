---
name: clean-branches
description: ローカルの不要なブランチ整理を依頼されたときに、保護対象と使用中のブランチを残してマージ済みブランチを削除する。
---

# ブランチ整理（Codex）

`~/.claude/skills/clean-branches/SKILL.md` を読み、共通の手順に従う。frontmatterの `model`・`allowed-tools` はClaude専用なので適用せず、Codexのシェルツールを使う。

未マージの候補は一覧と理由を報告して確認し、ユーザーが明示的に承認したものだけ強制削除する。Codexのフックが `git branch -D` の確認を求めたら、承認された対象であることを説明して `require_escalated` で再試行し、Codexの承認UIへ渡す。拒否された操作は迂回して実行しない。
