---
name: pr
description: ユーザーが $pr または /pr を指定してPR作成・更新を明示的に指示したターンで、変更をコミットしGitHubのPRを作成・更新する。使い方や設定の説明依頼では実行しない。
---

<!-- pr-mode-enable -->

# PR作成（Codex）

ユーザーがPR作成・更新を明示的に指示したとき、文中を含む `$pr`・`/pr`・旧 `/prompts:pr` の指定を、この環境の `/pr` 明示起動として扱う。`$pr` の使い方や設定の説明依頼ではcommit・push・PR操作を行わない。スキル指定のない自然言語の依頼だけでは実行せず、`$pr` の実行を案内する。

手順の実体は `~/.claude/skills/pr/SKILL.md`。このファイルを読み、次のCodex固有の読み替えを適用して最後まで実行する。

- Claudeの `allowed-tools`・モデル指定はCodexの権限設定ではない。シェル操作は利用可能なCodexツールを使う。
- フックは拒否専用で、自動承認しない。必要な承認はCodexのダイアログに従い、commit・push・PR操作を1つずつ独立して実行する。
- `AskUserQuestion` は利用可能なCodexの質問手段へ読み替える。質問ツールが使えずターンを終える必要があるときは、回答後にもう一度 `$pr` を実行するよう伝える。
- force push・デフォルトブランチへのpush・ブランチ削除・`--amend`・`--no-verify`・`gh pr merge` は使わない。サブエージェントへcommit・push・PR操作を委譲しない。
- PR本文などの複数行テキストは一時ファイルへ書き、`--body-file` で渡す。

作成・更新したPRのURL、ブランチ名、コミット一覧、検証結果を報告する。
