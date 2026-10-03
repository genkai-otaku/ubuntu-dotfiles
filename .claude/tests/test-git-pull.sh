#!/usr/bin/env bash
set -u

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/git-pull/scripts" && pwd)/git-pull.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/git-pull-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$tmp/gitconfig"
export GIT_TERMINAL_PROMPT=0
git config --global user.name "git-pull test"
git config --global user.email "git-pull-test@example.invalid"
git config --global pull.rebase true

origin="$tmp/origin.git"
seed="$tmp/seed"
workspace="$tmp/workspace"
current_workspace="$tmp/current-workspace"
writer="$tmp/writer"
mkdir -p "$workspace" "$current_workspace"

git init -q --bare --initial-branch=main "$origin" || exit 2
git init -q --initial-branch=main "$seed" || exit 2
echo initial >"$seed/README.md"
git -C "$seed" add README.md && git -C "$seed" commit -qm initial || exit 2
git -C "$seed" remote add origin "$origin" && git -C "$seed" push -qu origin main || exit 2

git clone -q "$origin" "$workspace/updatable" || exit 2
git clone -q "$origin" "$workspace/dirty" || exit 2
git clone -q "$origin" "$workspace/diverged" || exit 2
git clone -q "$origin" "$current_workspace/current-sync" || exit 2
git clone -q "$origin" "$writer" || exit 2

git -C "$workspace/updatable" checkout -qb feature || exit 2
git -C "$workspace/dirty" checkout -qb feature || exit 2
echo dirty >>"$workspace/dirty/README.md"
echo untracked >"$workspace/dirty/untracked.txt"

echo local >"$workspace/diverged/local.txt"
git -C "$workspace/diverged" add local.txt && git -C "$workspace/diverged" commit -qm local || exit 2
git -C "$current_workspace/current-sync" checkout -qb feature --track origin/main || exit 2
echo remote >"$writer/remote.txt"
git -C "$writer" add remote.txt && git -C "$writer" commit -qm remote && git -C "$writer" push -q origin main || exit 2

git init -q --initial-branch=develop "$workspace/no-main" || exit 2
echo develop >"$workspace/no-main/README.md"
git -C "$workspace/no-main" add README.md && git -C "$workspace/no-main" commit -qm develop || exit 2

set +e
current_output="$(bash "$SCRIPT" --current "$current_workspace" 2>&1)"
current_rc=$?
output="$(bash "$SCRIPT" "$workspace" 2>&1)"
rc=$?
set -u

passed=0
failed=0
check() {
  local name="$1" result="$2"
  if [ "$result" = yes ]; then
    passed=$((passed + 1))
  else
    printf '  NG %s\n' "$name"
    failed=$((failed + 1))
  fi
}

main_head="$(git -C "$workspace/updatable" rev-parse HEAD 2>/dev/null || true)"
origin_head="$(git --git-dir="$origin" rev-parse refs/heads/main 2>/dev/null || true)"
diverged_head="$(git -C "$workspace/diverged" rev-parse HEAD 2>/dev/null || true)"
local_diverged_head="$(git -C "$workspace/diverged" rev-parse refs/heads/main 2>/dev/null || true)"
dirty_status="$(git -C "$workspace/dirty" status --porcelain 2>/dev/null || true)"

check "fast-forward 更新が成功" "$([ "$main_head" = "$origin_head" ] && echo yes || echo no)"
current_head="$(git -C "$current_workspace/current-sync" rev-parse HEAD 2>/dev/null || true)"
check "current モードは upstream へ fast-forward" "$([ "$current_head" = "$origin_head" ] && echo yes || echo no)"
check "current モードは現在のブランチを維持" "$( [ "$(git -C "$current_workspace/current-sync" branch --show-current)" = feature ] && echo yes || echo no )"
check "current モードが成功終了" "$([ "$current_rc" -eq 0 ] && echo yes || echo no)"
check "更新したリポジトリは main に切替" "$( [ "$(git -C "$workspace/updatable" branch --show-current)" = main ] && echo yes || echo no )"
check "変更ありのリポジトリは feature のまま" "$( [ "$(git -C "$workspace/dirty" branch --show-current)" = feature ] && echo yes || echo no )"
check "変更ありの作業ツリーを保持" "$( [ -n "$dirty_status" ] && grep -q '^dirty$' "$workspace/dirty/README.md" && echo yes || echo no )"
check "main が無いリポジトリを変更しない" "$( [ "$(git -C "$workspace/no-main" branch --show-current)" = develop ] && echo yes || echo no )"
check "分岐時にローカルコミットを保持" "$( [ "$diverged_head" = "$local_diverged_head" ] && [ "$(git -C "$workspace/diverged" branch --show-current)" = main ] && echo yes || echo no )"
check "分岐を fast-forward 不可として報告" "$(case "$output" in *'fast-forward 不可'*) echo yes ;; *) echo no ;; esac)"
check "リポジトリ単位の失敗を非0で通知" "$([ "$rc" -eq 1 ] && echo yes || echo no)"

if [ "$failed" -eq 0 ]; then
  printf '  ✓ git-pull.sh: %s 件すべて通過\n' "$passed"
  exit 0
fi
printf '  ✗ git-pull.sh: %s/%s 件失敗\n' "$failed" "$((passed + failed))"
exit 1
