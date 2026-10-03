---
description: 明示的な /pr コマンドからPR作成手順を実行する
mode: primary
hidden: true
permissions:
  - action: shell
    resource: "git commit *"
    effect: allow
  - action: shell
    resource: "git push -u origin feat/*"
    effect: allow
  - action: shell
    resource: "git push -u origin feature/*"
    effect: allow
  - action: shell
    resource: "git push -u origin fix/*"
    effect: allow
  - action: shell
    resource: "git push -u origin bugfix/*"
    effect: allow
  - action: shell
    resource: "git push -u origin docs/*"
    effect: allow
  - action: shell
    resource: "git push -u origin chore/*"
    effect: allow
  - action: shell
    resource: "git push -u origin refactor/*"
    effect: allow
  - action: shell
    resource: "git push -u origin test/*"
    effect: allow
  - action: shell
    resource: "git push -u origin hotfix/*"
    effect: allow
  - action: shell
    resource: "git push -u origin perf/*"
    effect: allow
  - action: shell
    resource: "git push -u origin build/*"
    effect: allow
  - action: shell
    resource: "git push -u origin ci/*"
    effect: allow
  - action: shell
    resource: "git push -u origin style/*"
    effect: allow
  - action: shell
    resource: "git push -u origin revert/*"
    effect: allow
  - action: shell
    resource: "gh pr create *"
    effect: allow
  - action: shell
    resource: "git commit *--amend*"
    effect: deny
  - action: shell
    resource: "git commit *--no-verify*"
    effect: deny
  - action: shell
    resource: "git push *--force*"
    effect: deny
  - action: shell
    resource: "git push * -f*"
    effect: deny
  - action: shell
    resource: "git push -f*"
    effect: deny
  - action: shell
    resource: "git push *--delete*"
    effect: deny
  - action: shell
    resource: "git push *--mirror*"
    effect: deny
  - action: shell
    resource: "git push *--all*"
    effect: deny
  - action: shell
    resource: "git push *--tags*"
    effect: deny
  - action: shell
    resource: "git push *:*"
    effect: deny
---

このAgentは `/pr` コマンド専用です。コマンドから明示的に起動された場合だけ、`pr` Skillに従ってコミット・通常のorigin push・PR作成を行います。確認なしでpushできるブランチ名はSkillに定めるPR用prefix配下に限ります。それ以外のpushは確認を待ちます。許可ルールはこのAgentに限り、通常セッションには適用しません。

Skillにない変更、force push、デフォルトブランチへのpush、PRのマージは禁止です。別のGitHub書き込みや破壊的操作は許可しません。
