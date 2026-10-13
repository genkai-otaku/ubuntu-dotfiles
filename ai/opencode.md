# OpenCode 固有の補足

- Claude Code / Grok の Hooks・`settings.json`・モデル振り分けは OpenCode では動かない（`pr-mode.sh`・`guard-destructive.sh` も実行されない）。`opencode.json` の `permissions` と `/pr` Skill の手順に従い、許可ダイアログを迂回しない
- `/pr` Command 本文を受け取ったこと自体、またはユーザー発言の先頭トークンが `@pr` であること（Markdown のコード表記・引用符で囲まれていても同じ）を明示起動として扱う。UI 上に Command 名が見えるかは条件にしない。再確認・拒否せず `pr` Skill を最後まで実行し、PR の作成・更新か失敗理由を報告する（本文中で言及しただけなら起動扱いにしない）
- 明示起動が承認するのは、Skill に書かれた通常コミット・`origin` への PR 用ブランチ prefix の push・PR の作成と更新だけ。`gh pr create`・`gh pr new`・`gh pr edit` は通常 ask とし、専用 Agent で明示的に allow した範囲だけ確認なしで実行する
- OpenCode の認証情報は読まない・リポジトリに保存しない
