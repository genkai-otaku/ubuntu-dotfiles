---
description: ユーザーが明示的に起動したときだけ、変更をコミットしてGitHubへPRを作成する
agent: pr
subagent: false
---

`@pr` Skillを読み込み、その手順に従ってこのセッション内で実行してください。`/pr` の明示的な起動を、Skillに記載された通常のコミット・`origin` へのpush・PR作成の承認として扱います。force push・デフォルトブランチへのpush・PRのマージは禁止です。
