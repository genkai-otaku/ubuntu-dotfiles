#!/bin/bash
# codex/hooks/guard.sh（Codex CLI の安全装置フック）のテーブル駆動テスト
# 実行: bash .claude/tests/test-codex-guard.sh（run.sh からも呼ばれる）
# Codex は未導入なので、公式ドキュメントどおりの入力 JSON を模してフックの判定だけを検査する。
# フラグは TMPDIR 配下（lib.sh が一時ディレクトリに向ける）に作られる
set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
HOOK="$(cd "$TESTS_DIR/../../codex/hooks" && pwd)/guard.sh"
S_ON=test-codex-on-$$
S_OFF=test-codex-off-$$
cleanup() { rm -f "$T/codex-pr-mode-test-codex-"*; }
trap cleanup EXIT
cleanup

# shell ツールの command は配列（["bash","-lc","…"]）で届く形を既定にする
pre() { # label expected session cmd
  local out
  out=$(jq -cn --arg s "$3" --arg c "$4" \
    '{hook_event_name:"PreToolUse",session_id:$s,cwd:"/tmp",tool_name:"shell",tool_input:{command:["bash","-lc",$c]}}' \
    | bash "$HOOK" 2>/dev/null)
  report "$1" "$2" "$(decision_of "$out")" "$4"
}
prompt() { # session text
  jq -cn --arg s "$1" --arg p "$2" '{hook_event_name:"UserPromptSubmit",session_id:$s,cwd:"/tmp",prompt:$p}' \
    | bash "$HOOK" >/dev/null 2>&1
}
ev() { # session event
  jq -cn --arg s "$1" --arg e "$2" '{hook_event_name:$e,session_id:$s,cwd:"/tmp"}' | bash "$HOOK" >/dev/null 2>&1
}

PR_MARKER=$(grep -m1 'pr-mode-enable' "$(cd "$TESTS_DIR/../../codex/prompts" && pwd)/pr.md")
[ -n "$PR_MARKER" ] || { echo "  NG [A00] codex/prompts/pr.md のマーカーが読めません（guard.sh が /pr の起動を判定できない）"; FAIL=$((FAIL+1)); }

echo "# A. /pr の起動（マーカー・先頭の /pr）でフラグが立つ"
prompt "$S_ON" "$PR_MARKER"$'\n\n手順に従って実行してください'
[ -f "$T/codex-pr-mode-$S_ON" ] && r=yes || r=no
report A01-marker yes "$r" "$PR_MARKER"
S2=test-codex-slash-$$
prompt "$S2" "/pr"
[ -f "$T/codex-pr-mode-$S2" ] && r=yes || r=no
report A02-slash-pr yes "$r" ""
S3=test-codex-other-$$
prompt "$S3" "/pr 分け方はまかせる"
[ -f "$T/codex-pr-mode-$S3" ] && r=yes || r=no
report A03-slash-pr-args yes "$r" "先頭が /pr なら引数つきでも起動扱い"
prompt "$S3" "テストを直して"
[ -f "$T/codex-pr-mode-$S3" ] && r=yes || r=no
report A04-other-prompt-clears no "$r" "/pr 以外の発言では残骸フラグを消す"
S4=test-codex-prune-$$
prompt "$S4" "/prune してほしい"
[ -f "$T/codex-pr-mode-$S4" ] && r=yes || r=no
report A05-slash-prune no "$r" ""

echo "# B. /pr 外の拒否"
pre B01 deny "$S_OFF" 'git commit -m x'
pre B02 deny "$S_OFF" 'git push -u origin feat/x'
pre B03 deny "$S_OFF" 'gh pr create --fill'
pre B04 deny "$S_OFF" 'gh pr new --fill'
pre B05 deny "$S_OFF" 'gh pr edit 12 --body b'
pre B06 deny "$S_OFF" 'gh api -X POST repos/o/r/pulls -f title=t'
pre B07 none "$S_OFF" 'git status'
pre B08 none "$S_OFF" 'gh pr view 12'
pre B09 none "$S_OFF" 'npm test'

echo "# C. /pr 中でも常に拒否するもの"
pre C01 deny "$S_ON" 'git push --force origin feat/x'
pre C02 deny "$S_ON" 'git push -f origin feat/x'
pre C03 deny "$S_ON" 'git push --delete origin feat/x'
pre C04 deny "$S_ON" 'git push --mirror origin'
pre C05 deny "$S_ON" 'git push -u origin main'
pre C06 deny "$S_ON" 'git push origin master'
pre C07 deny "$S_ON" 'git commit --amend --no-edit'
pre C08 deny "$S_ON" 'git commit --no-verify -m x'
pre C09 deny "$S_ON" 'gh pr merge 12 --squash'
pre C10 deny "$S_ON" 'sudo apt-get install -y x'
pre C11 none "$S_ON" 'git commit -m "fix: x"'
pre C12 none "$S_ON" 'git push -u origin feat/x'
pre C13 none "$S_ON" 'gh pr edit 12 --title t'

echo "# D. フラグの寿命（Stop / SessionEnd で消える）"
ev "$S_ON" Stop
[ -f "$T/codex-pr-mode-$S_ON" ] && r=yes || r=no
report D01-stop no "$r" ""
pre D02-after-stop deny "$S_ON" 'git commit -m x'
prompt "$S_ON" "$PR_MARKER"
ev "$S_ON" SessionEnd
[ -f "$T/codex-pr-mode-$S_ON" ] && r=yes || r=no
report D03-session-end no "$r" ""

echo "# E. 異常入力（何も出さず exit 0）"
out=$(printf 'not json' | bash "$HOOK" 2>/dev/null); rc=$?
report E01-garbage "0:" "$rc:$out" ""
out=$(printf '' | bash "$HOOK" 2>/dev/null); rc=$?
report E02-empty "0:" "$rc:$out" ""
out=$(jq -cn '{hook_event_name:"PreToolUse",session_id:"../x",tool_name:"shell",tool_input:{command:["git","commit"]}}' | bash "$HOOK" 2>/dev/null); rc=$?
report E03-bad-session "0:" "$rc:$out" "不正な session_id では何もしない"
# command が文字列で届く実装でも同じ判定になる
out=$(jq -cn --arg s "$S_OFF" '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"shell",tool_input:{command:"git commit -m x"}}' | bash "$HOOK" 2>/dev/null)
report E04-string-command deny "$(decision_of "$out")" "$out"
out=$(jq -cn --arg s "$S_OFF" '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"apply_patch",tool_input:{command:"git commit -m x"}}' | bash "$HOOK" 2>/dev/null)
report E05-other-tool deny "$(decision_of "$out")" "shell 以外の matcher でも拒否は同じ（hooks.json は shell だけ登録）"

cleanup
summary "codex-guard.sh"
