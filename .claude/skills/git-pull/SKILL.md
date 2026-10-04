---
name: git-pull
description: 複数リポジトリを安全に更新する。既定は全リポジトリを main に切り替えて pull。現在のブランチを維持する更新もこのSkillで行う。
---

# 複数リポジトリの更新

ワークスペース自身と直下の独立した Git リポジトリを更新する。走査対象はルート自身と直下のみ。

## 更新モード

- `main` モードを既定とする。ユーザーがSkillの実行だけを依頼した場合、`/git-pull` 単独の場合、「リポジトリを最新に」「Git を同期」などの依頼では `main` モードを使う。
- ユーザーが「現在のブランチを維持」など、ブランチを切り替えないことを明示した場合に限り `current` モードを使う。
- ユーザーが `main` 以外の特定ブランチを指定した場合は、指定に沿う安全な方法がSkillに定義されていないため、実行前に確認する。

## 手順

1. CWD をワークスペースルートとして、該当するスクリプトを1回実行する。

   ```bash
   # main モード
   bash ~/.claude/skills/git-pull/scripts/git-pull.sh --main "$PWD"

   # current モード
   bash ~/.claude/skills/git-pull/scripts/git-pull.sh --current "$PWD"
   ```

2. スクリプトの終了を待ち、標準出力の結果表をそのまま報告する。失敗行がある場合は表示された理由を添える。
3. 終了コードが非0でも、結果表を報告する。失敗したリポジトリを別のコマンドで pull し直したり、状態を直したりしない。

## 共通の安全条件

- 未コミット・未追跡の変更があるリポジトリはスキップする。
- detached HEAD は `current` モードでスキップする。
- 履歴が fast-forward できない場合は失敗として報告し、stash・reset・rebase・強制 checkout で解決しない。
- 失敗したリポジトリの状態を別コマンドで変更しない。

## モードごとの動作

- `main`：ローカル `main` とその upstream がある場合だけ `main` に切り替え、`git pull --no-rebase --ff-only` する。`main` がない場合はスキップする。pull 失敗後に元のブランチへ戻さない。
- `current`：現在のブランチを維持して `git fetch --prune` し、upstream があれば `git merge --ff-only` する。upstream がなければ fetch のみ行う。detached HEAD はスキップする。
