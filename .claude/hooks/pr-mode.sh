#!/bin/bash

# /pr モード管理フック（Claude Code / Grok CLI）
#
# /pr 実行中だけ git commit / git push / gh pr create を許可する。
# gh pr merge は自動許可しない（Claude は permissions.ask へ落とす。
# Grok は確認が無いのでフラグ無しなら PreToolUse で deny）。
# force push（--force / -f / --force-with-lease）は /pr 中でも許可しない。
#
# Claude Code:
# - UserPromptExpansion: command_name が pr ならフラグ作成、別コマンドなら削除
#   （UserPromptSubmit の prompt は展開後のスキル本文なので、スラッシュコマンド名の
#     判定は Expansion の command_name が正）
# - UserPromptSubmit: 前ターンの残骸フラグを掃除（立てた直後のものは残す）
# - PermissionRequest: フラグがあれば対象の単一コマンドを behavior=allow で
#   自動承認する（PreToolUse の permissionDecision=allow では permissions.ask を
#   上書きできない）。複合コマンドと gh pr merge は確認へ落とす。
#   フラグが無ければ git commit / git push / gh pr create を deny
# - PreToolUse: force push だけ deny（ask で通さない）。
#   判定は引用符内と HEREDOC 本文を除いてから行う
# - Stop: ターン終了時にフラグ削除
#
# Grok:
# - UserPromptExpansion / PermissionRequest は無い
# - stdin は camelCase、イベント名は GROK_HOOK_EVENT
# - UserPromptSubmit: 先頭 /pr、または番兵 <!-- pr-mode-enable --> でフラグ作成。
#   それ以外の非空 prompt ではフラグ削除
# - PreToolUse: フラグが無ければ対象コマンドを deny（always-approve でも止まる）
# - Stop: フラグ削除
#
# フラグ: ${TMPDIR:-/tmp}/claude-pr-mode-<session_id>

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // .hookEventName // empty')
if [ -z "$event" ] && [ -n "${GROK_HOOK_EVENT:-}" ]; then
  event="$GROK_HOOK_EVENT"
fi
case "$event" in
  user_prompt_expansion) event=UserPromptExpansion ;;
  user_prompt_submit) event=UserPromptSubmit ;;
  permission_request) event=PermissionRequest ;;
  pre_tool_use) event=PreToolUse ;;
  stop) event=Stop ;;
esac

session="${GROK_SESSION_ID:-}"
if [ -z "$session" ]; then
  session=$(printf '%s' "$input" | jq -r '.session_id // .sessionId // "unknown"')
fi
flag="${TMPDIR:-/tmp}/claude-pr-mode-${session}"

cmd_name=$(printf '%s' "$input" | jq -r '.command_name // .commandName // empty')
prompt=$(printf '%s' "$input" | jq -r '.prompt // .user_prompt // .userPrompt // empty')
tool_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // .toolInput.command // empty')
subagent=$(printf '%s' "$input" | jq -r '.subagentType // .subagent_type // empty')

is_pr=0
if [ "$cmd_name" = "pr" ]; then
  is_pr=1
else
  case "$prompt" in
    *'<!-- pr-mode-enable -->'*) is_pr=1 ;;
  esac
  if [ "$is_pr" -eq 0 ]; then
    first=$(printf '%s\n' "$prompt" | sed -n '1p' | tr -d '\r')
    first="${first#"${first%%[![:space:]]*}"}"
    case "$first" in
      /pr|/pr[[:space:]]*) is_pr=1 ;;
    esac
  fi
fi

# git/gh のサブコマンドを、先頭の env 代入と git/gh グローバルオプションを剥がして取る。
# `git stash push` を push 扱いしない。引用符は無視して空白分割する（十分）。
git_or_gh_sub() {
  local -a w
  local i=0 bin sub
  read -r -a w <<< "$1"
  while [ "$i" -lt "${#w[@]}" ]; do
    case "${w[$i]}" in
      *=*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  bin="${w[$i]:-}"
  bin="${bin##*/}"
  i=$((i + 1))
  case "$bin" in
    git)
      while [ "$i" -lt "${#w[@]}" ]; do
        case "${w[$i]}" in
          -c|-C|--git-dir|--work-tree|--namespace|--super-prefix|--config-env)
            i=$((i + 2)) ;;
          --git-dir=*|--work-tree=*|--namespace=*|--super-prefix=*|--config-env=*)
            i=$((i + 1)) ;;
          -*)
            i=$((i + 1)) ;;
          *)
            break ;;
        esac
      done
      printf '%s' "${w[$i]:-}"
      ;;
    gh)
      while [ "$i" -lt "${#w[@]}" ]; do
        case "${w[$i]}" in
          --repo|-R|--hostname)
            i=$((i + 2)) ;;
          --repo=*|--hostname=*)
            i=$((i + 1)) ;;
          -*)
            i=$((i + 1)) ;;
          *)
            break ;;
        esac
      done
      if [ "${w[$i]:-}" = "pr" ]; then
        printf 'pr %s' "${w[$((i + 1))]:-}"
      else
        printf '%s' "${w[$i]:-}"
      fi
      ;;
  esac
}

is_guarded_git=0
sub=$(git_or_gh_sub "$tool_cmd")
case "$sub" in
  commit|push|"pr create"|"pr merge") is_guarded_git=1 ;;
esac
# bash -c 'git commit ...' など、ラッパー越しは部分一致に倒す
if [ "$is_guarded_git" -eq 0 ]; then
  case "$tool_cmd" in
    *"git commit"*|*"git push"*|*"gh pr create"*|*"gh pr merge"*) is_guarded_git=1 ;;
  esac
fi

# フラグはフックだけが作る。エージェントが touch / リダイレクトで迂回するのを止める。
# git commit / gh pr create の本文にフラグ名が出るだけでは deny しない
is_flag_tamper=0
if [ "$is_guarded_git" -eq 0 ]; then
  case "$tool_cmd" in
    *claude-pr-mode-*) is_flag_tamper=1 ;;
  esac
fi

# 引用符内と HEREDOC 本文を除く。コミットメッセージや PR 本文の
# --force リテラルで force push と誤判定しないため
strip_quoted_and_heredoc() {
  printf '%s\n' "$1" | awk '
    hd != "" {
      line = $0
      sub(/^\t+/, "", line)
      if (line == hd) hd = ""
      next
    }
    {
      if (match($0, /<<-?[ \t]*['\''"]?[A-Za-z_][A-Za-z0-9_]*/)) {
        tag = substr($0, RSTART, RLENGTH)
        sub(/<<-?[ \t]*['\''"]?/, "", tag)
        hd = tag
      }
      print
    }
    END { if (hd != "") print ";" }   # 終端が見つからないHEREDOCは安全側へ
  ' | sed -E "s/'[^']*'//g" | sed -E 's/"(\\.|[^"\\])*"//g'
}

cmd_stripped=$(strip_quoted_and_heredoc "$tool_cmd")

# 自動許可は git commit / git push / gh pr create の単一コマンドに限る。
# gh pr merge は ask に落とす（スキル手順外）
is_pr_auto_allow=0
case "$sub" in
  commit|push|"pr create") is_pr_auto_allow=1 ;;
esac
if [ "$is_pr_auto_allow" -eq 0 ]; then
  case "$sub" in
    "pr merge") ;;
    *)
      case "$tool_cmd" in
        *"git commit"*|*"git push"*|*"gh pr create"*) is_pr_auto_allow=1 ;;
      esac
      ;;
  esac
fi

# 複合コマンドは自動許可しない（decision がリクエスト全体に掛かるため）。
# 2>&1 / <& / &> のリダイレクト単体は複合とみなさない
is_composite=0
case "$cmd_stripped" in
  *'&&'* | *'||'* | *';'* | *'|'* ) is_composite=1 ;;
esac
if [ "$is_composite" -eq 0 ]; then
  case "$cmd_stripped" in
    *'&'*)
      case "$cmd_stripped" in
        *'>&'*|*'<&'*|*'&>'*) ;;
        *) is_composite=1 ;;
      esac
      ;;
  esac
fi

is_force_push=0
if [ "$sub" = "push" ] || case "$cmd_stripped" in *"git push"*) true ;; *) false ;; esac; then
  case "$cmd_stripped" in
    *" --force"*|*" --force-with-lease"*) is_force_push=1 ;;
  esac
  if [ "$is_force_push" -eq 0 ]; then
    saw_push=0
    for t in $cmd_stripped; do
      [ "$t" = "push" ] && saw_push=1
      if [ "$saw_push" -eq 1 ]; then
        case "$t" in
          -f|--force|--force-with-lease|--force=*|--force-with-lease=*)
            is_force_push=1
            break
            ;;
        esac
      fi
    done
  fi
fi

deny_reason='/pr の指示があるまで git commit / git push / gh pr create / gh pr merge は禁止されています'
force_reason='force push は禁止されています'
flag_reason='pr-mode フラグはフック以外が作成・変更してはならない'
if [ -n "${GROK_HOOK_EVENT:-}" ]; then
  deny_msg=$(printf '{"decision":"deny","reason":"%s"}' "$deny_reason")
  deny_force=$(printf '{"decision":"deny","reason":"%s"}' "$force_reason")
  deny_flag=$(printf '{"decision":"deny","reason":"%s"}' "$flag_reason")
else
  # Claude
  deny_msg=$(printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$deny_reason")
  deny_force=$(printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$force_reason")
  deny_flag=$(printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$flag_reason")
fi

case "$event" in
  UserPromptExpansion)
    if [ "$is_pr" -eq 1 ]; then
      touch "$flag"
    else
      rm -f "$flag"
    fi
    ;;
  UserPromptSubmit)
    # サブエージェントの submit で親のフラグを消さない
    if [ -n "$subagent" ] && [ "$subagent" != "null" ]; then
      exit 0
    fi
    if [ "$is_pr" -eq 1 ]; then
      touch "$flag"
    elif [ -n "${GROK_HOOK_EVENT:-}" ]; then
      # Grok は Expansion が無いので、ユーザー発話が /pr でなければ閉じる。
      # prompt が空の auto-wake では触らない
      if [ -n "$prompt" ]; then
        rm -f "$flag"
      fi
    elif [ -f "$flag" ]; then
      now=$(date +%s)
      mtime=$(stat -c %Y "$flag" 2>/dev/null || echo 0)
      if [ $((now - mtime)) -gt 15 ]; then
        rm -f "$flag"
      fi
    fi
    ;;
  PermissionRequest)
    if [ -f "$flag" ]; then
      if [ "$is_pr_auto_allow" -eq 1 ] && [ "$is_force_push" -eq 0 ] && [ "$is_composite" -eq 0 ]; then
        echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
      fi
    elif [ "$is_pr_auto_allow" -eq 1 ]; then
      echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"コミット・push・PR作成はユーザーが /pr を実行しているターンでのみ許可されます。ユーザーに /pr の実行を依頼してください。"}}}'
    fi
    ;;
  PreToolUse)
    if [ "$is_flag_tamper" -eq 1 ]; then
      echo "$deny_flag"
    elif [ "$is_force_push" -eq 1 ]; then
      # force push は Claude の ask 許可でも通さない
      echo "$deny_force"
    elif [ -n "${GROK_HOOK_EVENT:-}" ]; then
      # git commit / push / PR 作成の deny は Grok（always-approve でも止まる）。
      # Claude は PermissionRequest で ask を代替する
      if [ "$is_guarded_git" -eq 1 ] && [ ! -f "$flag" ]; then
        echo "$deny_msg"
      fi
    fi
    ;;
  Stop)
    rm -f "$flag"
    ;;
esac

exit 0
