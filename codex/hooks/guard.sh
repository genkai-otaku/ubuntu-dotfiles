#!/bin/bash
# Codex の PR 操作ガード。PreToolUse は拒否だけを返し、承認は Codex の UI に任せる。
# 通常の CLI 操作の事故防止が対象。難読化による回避は対象外。
# フラグはセッションとターンで照合する。PreToolUse に agent_id が届かない環境では
# サブエージェントを判別できないため、委譲禁止は ai/codex.md の指示でも守る。
exec 2>/dev/null
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
fields=$(printf '%s' "$input" | jq -r '
  (.tool_input | if type == "object" then . else {} end) as $ti
  | [(.hook_event_name // ""), (.session_id // ""), (.turn_id // ""),
     ($ti.command // $ti.cmd // "" | if type == "array" then (if length >= 3 and (.[0] | test("(^|/)(bash|sh|zsh)$")) and (.[1] | test("^-[A-Za-z]*c[A-Za-z]*$")) then .[2] else join(" ") end) elif type == "string" then . else "" end),
     (.prompt // .user_prompt // ""), (.agent_id // "")]
  | map(tostring) | @sh') || exit 0
eval "set -- $fields" || exit 0
event="$1" session="$2" turn="$3" cmd="$4" prompt="$5" agent="$6"
[[ "$session" =~ ^[A-Za-z0-9._-]+$ ]] || exit 0
FLAG="${TMPDIR:-/tmp}/codex-pr-mode-${session}"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="$(cd "$(dirname "$SELF")/../.." && pwd -P)" || exit 0
STRIP_AWK="$ROOT/.claude/hooks/lib/strip-shell.awk"
source "$ROOT/.claude/hooks/lib/git-write.sh" || exit 0

deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
case "$event" in
  UserPromptSubmit)
    [ -z "$agent" ] || exit 0
    # スキル指定は文中でも有効。スラッシュコマンドは先頭の語だけを起動とする。
    if printf '%s\n' "$prompt" | grep -Eq '(^|[[:space:]])\$pr([[:space:]]|$)' \
      || [[ "$prompt" =~ ^[[:space:]]*(/pr|/prompts:pr)([[:space:]]|$) ]]; then
      printf '%s' "$turn" >"$FLAG"
    else
      case "$prompt" in
        *'<!-- pr-mode-enable -->'*) printf '%s' "$turn" >"$FLAG" ;;
        *) [ -n "$prompt" ] && rm -f "$FLAG" ;;
      esac
    fi
    exit 0 ;;
  Stop | SessionEnd)
    [ -z "$agent" ] && rm -f "$FLAG"
    exit 0 ;;
  PreToolUse) ;;
  *) exit 0 ;;
esac
[ -n "$cmd" ] || exit 0
s=$(stripped_or_raw "$cmd")
s=${s//\\$'\n'/ }
s=${s//$'\n'/;}
# 共通の判定で -C / -c 等を認識し、常時拒否の検査にも同じ通常形式を使う。
gitopt='((-[cC]|--git-dir|--work-tree|--namespace)[[:space:]]+[^[:space:]]+[[:space:]]+|--?[A-Za-z][^[:space:]]*[[:space:]]+)*'
w=$(printf '%s\n' "$s" | sed -E "s@(^|[[:space:];&|(])([^[:space:]]*/)?\\\\?git[[:space:]]+${gitopt}(commit|push)([[:space:];&|)]|$)@\\1git \\5\\6@g")
w=$(printf '%s' "$w" | tr ';|&()' ' ')
w=" $w "
printf '%s\n' "$s" | grep -Eq '(^|[[:space:];&|(])sudo([[:space:];&|)]|$)' && deny 'sudo は使えません。必要なコマンドをユーザーに示してください。'
case "$w" in *"gh pr merge"*) deny 'PR のマージはユーザーに任せてください。' ;; esac
if is_force_push "$cmd"; then deny 'force push は禁止です（/pr 中でも拒否します）。'; fi
case "$w" in
  *"git push"*)
    case "$w" in
      *" --mirror "* | *" --delete "* | *" -d "*) deny 'リモートブランチの削除・--mirror は禁止です。' ;;
      *" --no-verify "*) deny '--no-verify は使いません。' ;;
      *" origin main "* | *" origin master "* | *":main "* | *":master "* | *":refs/heads/main "* | *":refs/heads/master "*) deny 'デフォルトブランチへの push は禁止です。PR 用ブランチを使ってください。' ;;
    esac ;;
  *"git commit"*)
    case "$w" in *" --amend "* | *" --no-verify "* | *" -n "*) deny '--amend / --no-verify は使いません。' ;; esac ;;
esac
if [ -n "$agent" ] && is_git_write "$cmd" "$s"; then
  deny 'コミット・push・PR の作成と更新はメインセッションが直接実行してください。'
fi
if [ ! -f "$FLAG" ] || [ "$(cat "$FLAG")" != "$turn" ]; then
  is_git_write "$cmd" "$s" && deny '/pr を起動していないターンでは、コミット・push・PR の作成と更新はできません。変更をワーキングツリーに残し、ユーザーに /pr の実行を案内してください。'
fi
exit 0
