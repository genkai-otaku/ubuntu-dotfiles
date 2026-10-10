#!/bin/bash

# Codex CLI の安全装置フック（実体は dotfiles の codex/hooks/guard.sh。~/.codex/hooks/guard.sh はここへのリンク）。
#
# 契約: Claude Code の pr-mode.sh / guard-destructive.sh と同じ約束を Codex でも成り立たせる。
#   - /pr プロンプトを起動したターン以外では、コミット・push・PR の作成と更新を拒否する
#   - force push・デフォルトブランチ（main / master）宛の push・ブランチ削除・PR のマージ・
#     sudo・--amend / --no-verify は /pr 中でも拒否する
# Codex の PreToolUse は拒否だけで承認はできない（Codex 自身の承認ダイアログはそのまま出る）。
#
# 対象は「Codex がふつうに書くコマンドによる事故の防止」だけ。難読化（エスケープ・引用符で割った
# コマンド語など）による回避は対象外（グローバル指示の「レビューの範囲」）。
#
# 登録イベント（codex/hooks.json）と役割:
#   UserPromptSubmit … プロンプトが /pr の起動なら ${TMPDIR:-/tmp}/codex-pr-mode-<session_id> を作る
#   PreToolUse(shell) … 上記の契約で判定する
#   Stop / SessionEnd … フラグを消す（ターンをまたいだコミット・push を許さない）
# jq が無い・入力が壊れている・session_id が不正なら何もしない（exit 0）。

exec 2>/dev/null
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
[ -n "$input" ] || exit 0

# 使うフィールドをまとめて取り出す。shell ツールの command は配列（["bash","-lc","…"]）でも
# 文字列でも届くため、配列なら空白で連結する
fields=$(printf '%s' "$input" | jq -r '
  (.tool_input | if type == "object" then . else {} end) as $ti
  | [ (.hook_event_name // ""), (.session_id // ""),
      ($ti.command | if type == "array" then join(" ") elif type == "string" then . else "" end),
      (.prompt // .user_prompt // "") ]
  | map(tostring) | @sh') || exit 0
eval "set -- $fields" || exit 0
event="$1" session="$2" cmd="$3" prompt="$4"
[[ "$session" =~ ^[A-Za-z0-9._-]+$ ]] || exit 0

FLAG="${TMPDIR:-/tmp}"
FLAG="${FLAG%/}/codex-pr-mode-${session}"

# 拒否を返して終わる（permissionDecisionReason は Codex がモデルに見せる）
deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

case "$event" in
  UserPromptSubmit)
    # /pr の起動は、prompts/pr.md に埋め込んだマーカーか、発言の先頭の /pr で見分ける。
    # それ以外の発言ではフラグを消す（Stop が走らずに残った残骸で次のターンを通さない）
    case "$prompt" in
      *'<!-- pr-mode-enable -->'* | /pr | /pr[[:space:]]*) : >"$FLAG" ;;
      *) [ -n "$prompt" ] && rm -f "$FLAG" ;;
    esac
    exit 0
    ;;
  Stop | SessionEnd)
    rm -f "$FLAG"
    exit 0
    ;;
  PreToolUse) ;;
  *) exit 0 ;;
esac

[ -n "$cmd" ] || exit 0

# コマンド語の判定は空白で囲んで見る（引用符の中までは追わない。事故防止の範囲）
w=" $cmd "

# /pr 中でも常に拒否するもの
case "$w" in
  *" sudo "*) deny "sudo は使えません。必要な操作はコマンドを示してユーザーに依頼してください。" ;;
esac
case "$w" in
  *"gh pr merge"*) deny "PR のマージはユーザーの明示的な指示があるときだけです。PR の URL を報告してユーザーに任せてください。" ;;
esac
case "$w" in
  *"git push"*)
    case "$w" in
      *" -f "* | *" --force "* | *" --force-with-lease"* | *" --force-if-includes "*)
        deny "force push は禁止です（/pr 中でも拒否します）。" ;;
      *" --mirror "* | *" --delete "* | *" -d "*)
        deny "リモートブランチの削除・--mirror は禁止です。" ;;
      *" --no-verify "*)
        deny "--no-verify は使いません。フックを通したまま push してください。" ;;
      *" origin main "* | *" origin master "*)
        deny "デフォルトブランチへの push は禁止です。PR 用のブランチを作って push してください。" ;;
    esac
    ;;
esac
case "$w" in
  *"git commit"*)
    case "$w" in
      *" --amend "* | *" --no-verify "* | *" -n "*)
        deny "--amend / --no-verify は使いません（履歴を書き換えずに新しいコミットを作ってください）。" ;;
    esac
    ;;
esac

# /pr の起動が無いターンでの git / GitHub への書き込み
if [ ! -f "$FLAG" ]; then
  reason="/pr を起動していないターンでは、コミット・push・PR の作成と更新はできません。変更はワーキングツリーに残して内容を報告し、ユーザーに /pr の実行を案内してください。"
  case "$w" in
    *"git commit"* | *"git push"* | *"gh pr create"* | *"gh pr new"* | *"gh pr edit"*) deny "$reason" ;;
  esac
  case "$w" in
    *"gh api"*)
      case "$w" in
        *"/pulls"*) deny "$reason" ;;
      esac
      ;;
  esac
fi

exit 0
