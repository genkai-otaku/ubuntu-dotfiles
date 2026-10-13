---
name: clean-branches
description: ローカルの不要なブランチ整理を依頼されたときに、保護対象と使用中のブランチを残してマージ済みブランチを削除する。
---

# ブランチ整理（Codex）

`~/.claude/skills/clean-branches/SKILL.md` を読み、共通の手順に従う。frontmatterの `model`・`allowed-tools` はClaude専用なので適用せず、Codexのシェルツールを使う。

未マージの候補は一覧と理由を報告する。Codexのフックは `git branch -D` などの確認対象を常に拒否するため、対象コマンドと理由を示してユーザーに手動実行を依頼する。拒否された操作は迂回して実行しない。
