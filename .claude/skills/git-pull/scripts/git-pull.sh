#!/usr/bin/env bash
# ワークスペース自身と直下の独立した Git リポジトリを更新する。
# --main は main に切り替えて pull、--current は現在のブランチを fetch/ff-only する。
set -u
shopt -s nullglob

usage() {
  echo "Usage: $0 [--main|--current] [workspace-root]" >&2
  exit 2
}

mode="main"
root="$PWD"
case "$#" in
  0) ;;
  1)
    case "$1" in
      --main) mode="main" ;;
      --current) mode="current" ;;
      -h|--help) usage ;;
      *) root="$1" ;;
    esac
    ;;
  2)
    case "$1" in
      --main) mode="main" ;;
      --current) mode="current" ;;
      *) usage ;;
    esac
    root="$2"
    ;;
  *) usage ;;
esac

if [ ! -d "$root" ] || ! root="$(cd -- "$root" && pwd -P)"; then
  echo "ワークスペースディレクトリが見つかりません: $root"
  exit 2
fi

is_repo_root() {
  local dir="$1" canonical top
  canonical="$(cd -- "$dir" 2>/dev/null && pwd -P)" || return 1
  git -C "$canonical" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  top="$(git -C "$canonical" rev-parse --show-toplevel 2>/dev/null)" || return 1
  [ "$top" = "$canonical" ]
}

collect_repos() {
  local child canonical
  if is_repo_root "$root"; then
    printf '%s\0' "$root"
  fi
  for child in "$root"/*/; do
    [ -d "$child" ] || continue
    canonical="$(cd -- "$child" 2>/dev/null && pwd -P)" || continue
    if is_repo_root "$canonical"; then
      printf '%s\0' "$canonical"
    fi
  done
}

escape_md() {
  printf '%s' "$1" | tr '\r\n' '  ' | sed 's/|/\\|/g; s/`/\\`/g'
}

relative_name() {
  if [ "$1" = "$root" ]; then
    printf '.'
  else
    printf '%s' "${1#"$root"/}"
  fi
}

failure_reason() {
  local action="$1" output="$2" code="$3"
  case "$output" in
    *"Not possible to fast-forward"*|*"Not possible to fast-forward, aborting"*)
      printf 'fast-forward 不可（履歴が分岐）' ;;
    *"Authentication failed"*|*"could not read Username"*|*"Permission denied"*|*"publickey"*)
      printf '認証またはアクセス権エラー' ;;
    *"Could not resolve host"*|*"Could not resolve proxy"*|*"Failed to connect"*|*"Connection timed out"*|*"Network is unreachable"*)
      printf 'ネットワーク接続エラー' ;;
    *"Your local changes"*|*"would be overwritten"*|*"uncommitted changes"*)
      printf '作業ツリーが変更されたため中断' ;;
    *)
      printf '%s 失敗（終了コード %s。出力は秘匿）' "$action" "$code" ;;
  esac
}

update_one() {
  local repo="$1" name branch dirty output code before after reason
  name="$(escape_md "$(relative_name "$repo")")"
  branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
  [ -n "$branch" ] || branch="(detached)"

  dirty="$(git -C "$repo" status --porcelain --untracked-files=all 2>/dev/null || true)"
  if [ -n "$dirty" ]; then
    printf '| %s | %s | スキップ | 未コミットまたは未追跡の変更あり |\n' \
      "$name" "$(escape_md "$branch")"
    return 0
  fi

  if ! git -C "$repo" show-ref --verify --quiet refs/heads/main; then
    printf '| %s | %s | スキップ | ローカル main ブランチなし |\n' \
      "$name" "$(escape_md "$branch")"
    return 0
  fi

  if ! git -C "$repo" rev-parse --verify --quiet 'main@{upstream}' >/dev/null; then
    printf '| %s | %s | スキップ | main の upstream 未設定 |\n' \
      "$name" "$(escape_md "$branch")"
    return 0
  fi

  before="$(git -C "$repo" rev-parse --short refs/heads/main 2>/dev/null || true)"
  output="$(LC_ALL=C git -C "$repo" checkout main 2>&1)"
  code=$?
  if [ "$code" -ne 0 ]; then
    reason="$(failure_reason 'git checkout main' "$output" "$code")"
    printf '| %s | %s | エラー | %s |\n' "$name" "$(escape_md "$branch")" "$(escape_md "$reason")"
    return 1
  fi

  branch="main"
  output="$(LC_ALL=C git -C "$repo" pull --no-rebase --ff-only 2>&1)"
  code=$?
  if [ "$code" -ne 0 ]; then
    reason="$(failure_reason 'git pull' "$output" "$code")"
    printf '| %s | %s | エラー | %s |\n' "$name" "$branch" "$(escape_md "$reason")"
    return 1
  fi

  after="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || true)"
  if [ "$before" = "$after" ]; then
    printf '| %s | %s | 最新 | %s |\n' "$name" "$branch" "$after"
  else
    printf '| %s | %s | 更新 | %s..%s |\n' "$name" "$branch" "$before" "$after"
  fi
  return 0
}

update_current() {
  local repo="$1" name branch dirty output code before after reason upstream ahead behind
  name="$(escape_md "$(relative_name "$repo")")"
  branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
  if [ -z "$branch" ]; then
    printf '| %s | (detached) | スキップ | detached HEAD |\n' "$name"
    return 0
  fi

  dirty="$(git -C "$repo" status --porcelain --untracked-files=all 2>/dev/null || true)"
  if [ -n "$dirty" ]; then
    printf '| %s | %s | スキップ | 未コミットまたは未追跡の変更あり |\n' \
      "$name" "$(escape_md "$branch")"
    return 0
  fi

  output="$(LC_ALL=C git -C "$repo" fetch --prune 2>&1)"
  code=$?
  if [ "$code" -ne 0 ]; then
    reason="$(failure_reason 'git fetch' "$output" "$code")"
    printf '| %s | %s | エラー | %s |\n' "$name" "$(escape_md "$branch")" "$(escape_md "$reason")"
    return 1
  fi

  if ! upstream="$(git -C "$repo" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)"; then
    printf '| %s | %s | fetch のみ | upstream 未設定 |\n' "$name" "$(escape_md "$branch")"
    return 0
  fi

  before="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || true)"
  output="$(LC_ALL=C git -C "$repo" merge --ff-only "$upstream" 2>&1)"
  code=$?
  if [ "$code" -ne 0 ]; then
    reason="$(failure_reason 'git merge --ff-only' "$output" "$code")"
    printf '| %s | %s | エラー | %s |\n' "$name" "$(escape_md "$branch")" "$(escape_md "$reason")"
    return 1
  fi

  after="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || true)"
  if [ "$before" = "$after" ]; then
    read -r behind ahead <<<"$(git -C "$repo" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || echo '0 0')"
    if [ "${ahead:-0}" -gt 0 ]; then
      printf '| %s | %s | 最新 | %s（ローカルが %s コミット先行） |\n' \
        "$name" "$(escape_md "$branch")" "$after" "$ahead"
    else
      printf '| %s | %s | 最新 | %s |\n' "$name" "$(escape_md "$branch")" "$after"
    fi
  else
    printf '| %s | %s | 更新 | %s..%s |\n' "$name" "$(escape_md "$branch")" "$before" "$after"
  fi
  return 0
}

mapfile -d '' -t repos < <(collect_repos | LC_ALL=C sort -zu)
if [ "${#repos[@]}" -eq 0 ]; then
  echo "Git リポジトリが見つかりません: $(escape_md "$root")"
  exit 1
fi

echo "走査ルート: $(escape_md "$root")"
echo "モード: $mode"
echo "対象: ${#repos[@]} 件（ルート自身と直下のみ）"
echo
echo '| リポジトリ | ブランチ | 結果 | 詳細 |'
echo '|---|---|---|---|'

status=0
for repo in "${repos[@]}"; do
  if [ "$mode" = "main" ]; then
    update_one "$repo" || status=1
  else
    update_current "$repo" || status=1
  fi
done

exit "$status"
