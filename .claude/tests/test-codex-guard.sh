#!/bin/bash
# codex/hooks/guard.sh（Codex CLI の安全装置フック）のテーブル駆動テスト
# 実行: bash .claude/tests/test-codex-guard.sh（run.sh からも呼ばれる）
# 公式イベントの Bash 入力を使い、コマンド自体は実行せずフックの判定だけを検査する。
# フラグは TMPDIR 配下（lib.sh が一時ディレクトリに向ける）に作られる
set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
HOOK="$(cd "$TESTS_DIR/../../codex/hooks" && pwd)/guard.sh"
S_ON=test-codex-on-$$
S_OFF=test-codex-off-$$
cleanup() { rm -f "$T/codex-pr-mode-test-codex-"*; }
trap cleanup EXIT
cleanup

# 公式の Bash ツールでは command は文字列。旧 shell の配列は互換ケースで検査する。
pre() { # label expected session cmd
  local out
  out=$(jq -cn --arg s "$3" --arg c "$4" --arg t "${5-}" \
    '{hook_event_name:"PreToolUse",session_id:$s,turn_id:$t,cwd:"/tmp",tool_name:"Bash",tool_input:{command:$c}}' \
    | bash "$HOOK" 2>/dev/null)
  report "$1" "$2" "$(decision_of "$out")" "$4"
}
prompt() { # session text
  jq -cn --arg s "$1" --arg p "$2" --arg t "${3-}" '{hook_event_name:"UserPromptSubmit",session_id:$s,turn_id:$t,cwd:"/tmp",prompt:$p}' \
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
out=$(jq -cn '{hook_event_name:"PreToolUse",session_id:"../x",tool_name:"Bash",tool_input:{command:["git","commit"]}}' | bash "$HOOK" 2>/dev/null); rc=$?
report E03-bad-session "0:" "$rc:$out" "不正な session_id では何もしない"
# command が文字列で届く実装でも同じ判定になる
out=$(jq -cn --arg s "$S_OFF" '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"Bash",tool_input:{command:"git commit -m x"}}' | bash "$HOOK" 2>/dev/null)
report E04-string-command deny "$(decision_of "$out")" "$out"
out=$(jq -cn --arg s "$S_OFF" '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"apply_patch",tool_input:{command:"git commit -m x"}}' | bash "$HOOK" 2>/dev/null)
report E05-other-tool deny "$(decision_of "$out")" "判定本体はツール名に依存しない（hooks.json は Bash に登録）"

echo "# F. 通常のコマンドと公式の起動・ターン境界"
pre F01 deny "$S_OFF" 'git -C /tmp/example commit -m x'
pre F02 deny "$S_OFF" 'git -c core.quotePath=false push origin topic'
pre F03 none "$S_OFF" 'gh api repos/o/r/pulls/12'
pre F04 none "$S_OFF" 'gh api -X GET repos/o/r/pulls -f state=open'
pre F05 deny "$S_OFF" 'gh api repos/o/r/pulls/12 -X PATCH -f title=x'
pre F06 none "$S_OFF" "printf 'git commit -m x\\n'"
prompt "$S_ON" '$pr' turn-one
pre F07 none "$S_ON" 'git -C /tmp/example commit -m x' turn-one
pre F08 deny "$S_ON" 'git commit -m x' turn-two
pre F09 deny "$S_ON" 'git -C /tmp/example push --force origin topic' turn-one
pre F10 deny "$S_ON" 'git -c core.quotePath=false commit --amend -m x' turn-one
pre F11 deny "$S_ON" 'git push origin HEAD:main' turn-one
prompt "$S_ON" '/prompts:pr' turn-two
pre F12 none "$S_ON" 'git commit -m x' turn-two
out=$(jq -cn --arg s "$S_ON" '{hook_event_name:"PreToolUse",session_id:$s,turn_id:"turn-two",agent_id:"child",tool_name:"Bash",tool_input:{command:"git commit -m x"}}' | bash "$HOOK")
report F13-known-child deny "$(decision_of "$out")" "$out"
report F14-bash-registration Bash "$(jq -r '.hooks.PreToolUse[] | select(any(.hooks[]; .command | contains("guard.sh"))) | .matcher' "$TESTS_DIR/../../codex/hooks.json")" ""
pre F15 deny "$S_ON" 'git push origin main; git status' turn-two
pre F16 deny "$S_ON" 'git push -f; git status' turn-two
out=$(jq -cn --arg s "$S_OFF" '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"shell",tool_input:{command:["bash","-lc","printf \"git commit\"\n"]}}' | bash "$HOOK")
report F17-legacy-array none "$(decision_of "$out")" "$out"
prompt "$S_ON" '変更を確認して $pr を実行してください' turn-three
pre F18 none "$S_ON" 'git commit -m x' turn-three
prompt "$S_ON" '変更を $prune で整理してください' turn-four
pre F19 deny "$S_ON" 'git commit -m x' turn-four
prompt "$S_ON" '変更を確認して /pr を実行してください' turn-five
pre F20-inline-slash-pr deny "$S_ON" 'git commit -m x' turn-five
prompt "$S_ON" '変更を確認して /prompts:pr を実行してください' turn-six
pre F21-inline-prompts-pr deny "$S_ON" 'git commit -m x' turn-six
prompt "$S_ON" '変更を /profile で確認してください' turn-seven
pre F22-inline-profile deny "$S_ON" 'git commit -m x' turn-seven
prompt "$S_ON" '変更を /prompts:prune で整理してください' turn-eight
pre F23-inline-prompts-prune deny "$S_ON" 'git commit -m x' turn-eight
prompt "$S_ON" '/profile を確認してください' turn-nine
pre F24-leading-profile deny "$S_ON" 'git commit -m x' turn-nine
prompt "$S_ON" $' \t\n/pr 実行してください  ' turn-ten
pre F25-leading-whitespace-pr none "$S_ON" 'git commit -m x' turn-ten
prompt "$S_ON" $' \t\n/prompts:pr 実行してください  ' turn-eleven
pre F26-leading-whitespace-prompts-pr none "$S_ON" 'git commit -m x' turn-eleven
prompt "$S_ON" $'説明を短くして\n/pr を参照してください' turn-twelve
pre F27-second-line-pr deny "$S_ON" 'git commit -m x' turn-twelve
# Codex と同じく $pr の直前の文字は問わず、直後が [A-Za-z0-9_:-] 以外なら起動とする。
prompt "$S_ON" '$prでPRを作って' turn-thirteen
pre F28-skill-pr-before-japanese none "$S_ON" 'git commit -m x' turn-thirteen
prompt "$S_ON" '変更を$prで出して' turn-fourteen
pre F29-skill-pr-after-japanese none "$S_ON" 'git commit -m x' turn-fourteen
prompt "$S_ON" '$pr、お願い' turn-fifteen
pre F30-skill-pr-before-comma none "$S_ON" 'git commit -m x' turn-fifteen
prompt "$S_ON" '（$pr）' turn-sixteen
pre F31-skill-pr-in-parens none "$S_ON" 'git commit -m x' turn-sixteen
prompt "$S_ON" '変更を$pruneで整理して' turn-seventeen
pre F32-skill-prune-after-japanese deny "$S_ON" 'git commit -m x' turn-seventeen
prompt "$S_ON" '$pr-x を使って' turn-eighteen
pre F33-skill-pr-hyphen deny "$S_ON" 'git commit -m x' turn-eighteen
cleanup
pre G01 deny "$S_OFF" 'gh api "repos/o/r/pulls/12" -X "PATCH" -f title=x'
pre G02 deny "$S_OFF" 'gh api "repos/o/r/pulls" -X POST -f title=x'
pre G03 none "$S_OFF" 'gh api "repos/o/r/pulls/12" -X "GET"'
pre G04 deny "$S_OFF" 'echo gh api "repos/o/r/pulls/12" -X PATCH -f title=x'   # echo の引数のような文字列も書き込み扱い（単純化のため許容）
pre G05 deny "$S_OFF" 'gh api repos/o/r/pulls/12; echo gh api repos/o/r/pulls/12 -X PATCH'   # echo の引数のような文字列も書き込み扱い（単純化のため許容）
pre G06-api-braces deny "$S_OFF" '{ gh api repos/o/r/pulls -f title=x; }'
pre G07-api-then deny "$S_OFF" 'if true; then gh api repos/o/r/pulls -f title=x; fi'
pre G08-api-do deny "$S_OFF" 'for i in 1; do gh api repos/o/r/pulls -f title=x; done'
pre G09-api-negation deny "$S_OFF" '! gh api repos/o/r/pulls -f title=x'
pre G10-api-xargs deny "$S_OFF" 'echo x | xargs gh api repos/o/r/pulls -f title=x'
pre G11-api-else deny "$S_OFF" 'if false; then true; else gh api repos/o/r/pulls -f title=x; fi'
pre G12-api-elif deny "$S_OFF" 'if false; then true; elif gh api repos/o/r/pulls -f title=x; then true; fi'
pre G13-api-if deny "$S_OFF" 'if gh api repos/o/r/pulls -f title=x; then true; fi'
pre G14-api-while deny "$S_OFF" 'while gh api repos/o/r/pulls -f title=x; do break; done'
pre G15-api-until deny "$S_OFF" 'until gh api repos/o/r/pulls -f title=x; do break; done'
pre G16-api-braces-get none "$S_OFF" '{ gh api repos/o/r/pulls -X GET -f state=open; }'
pre G17-api-xargs-comments none "$S_OFF" 'echo x | xargs gh api repos/o/r/pulls/12/comments -f body=LGTM'
pre G18-api-heredoc-literal none "$S_OFF" $'cat <<\'EOF\'\n{ gh api repos/o/r/pulls -f title=x; }\nEOF'
pre G19-api-xargs-flags deny "$S_OFF" 'echo x | xargs -r -0 gh api repos/o/r/pulls -f title=x'
pre G20-api-xargs-attached-count deny "$S_OFF" 'echo x | xargs -n1 gh api repos/o/r/pulls -f title=x'
pre G21-api-xargs-attached-replace deny "$S_OFF" 'echo x | xargs -I{} gh api repos/o/r/pulls -f title=x'
pre G22-api-xargs-count deny "$S_OFF" 'echo x | xargs -n 1 gh api repos/o/r/pulls -f title=x'
pre G23-api-xargs-replace deny "$S_OFF" 'echo x | xargs -I {} gh api repos/o/r/pulls -f title=x'
pre G24-api-xargs-parallel deny "$S_OFF" 'echo x | xargs -P 4 gh api repos/o/r/pulls -f title=x'
pre G25-api-xargs-long-option deny "$S_OFF" 'echo x | xargs --max-args 1 gh api repos/o/r/pulls -f title=x'
pre G26-api-xargs-end-options deny "$S_OFF" 'echo x | xargs -- gh api repos/o/r/pulls -f title=x'
pre G27-api-xargs-option-get none "$S_OFF" 'echo x | xargs -r -n 1 gh api repos/o/r/pulls -X GET -f state=open'
pre G28-api-xargs-option-comments none "$S_OFF" 'echo x | xargs -I{} gh api repos/o/r/pulls/12/comments -f body=LGTM'
pre G29-api-xargs-command-boundary deny "$S_OFF" 'echo x | xargs -n 1 echo example; echo gh api repos/o/r/pulls -f title=x'   # echo の引数のような文字列も書き込み扱い（単純化のため許容）
pre G30-api-xargs-combined-next deny "$S_OFF" 'echo x | xargs -rn 1 gh api repos/o/r/pulls -f title=x'
pre G31-api-xargs-combined-attached deny "$S_OFF" 'echo x | xargs -r0n1 gh api repos/o/r/pulls -f title=x'
pre G32-api-xargs-combined-options deny "$S_OFF" 'echo x | xargs -0n 1 -P 4 gh api repos/o/r/pulls -f title=x'
pre G33-api-xargs-combined-get none "$S_OFF" 'echo x | xargs -rn 1 gh api repos/o/r/pulls -X GET -f state=open'
# 改行はコマンド境界、行継続は同じコマンド、引用内改行は引数として扱う。
pre H01-api-newline-write deny "$S_OFF" $'git status\ngh api "repos/o/r/pulls/12" -X PATCH -f title=x'
pre H02-api-newline-literal deny "$S_OFF" $'gh api repos/o/r/pulls/12\necho gh api repos/o/r/pulls/12 -X PATCH'   # echo の引数のような文字列も書き込み扱い（単純化のため許容）
pre H03-api-continuation deny "$S_OFF" $'gh api "repos/o/r/pulls/12" \\\n-X "PATCH" -f title=x'
pre H04-api-multiline-echo none "$S_OFF" $'echo "PRの説明\ngh api repos/o/r/pulls/12 -X PATCH"'
pre H05-api-multiline-body none "$S_OFF" $'gh api repos/o/r/pulls/12 -X GET -f body="利用例\ngh api repos/o/r/pulls/12 -X PATCH"'
# 前置き語（timeout / nix develop -c 等）を問わず、引用値の括弧は区切りにしない。区切りの後の語は別の区間として見る。
pre I01-api-timeout deny "$S_OFF" 'timeout 60 gh api repos/o/r/pulls -f title=x'
pre I02-api-nix-develop deny "$S_OFF" 'nix develop -c gh api repos/o/r/pulls -f title=x'
pre I03-api-direnv-exec deny "$S_OFF" 'direnv exec . gh api repos/o/r/pulls -f title=x'
pre I04-api-env-unset deny "$S_OFF" 'env -u GITHUB_TOKEN gh api repos/o/r/pulls -f title=x'
pre I05-api-nice deny "$S_OFF" 'nice gh api repos/o/r/pulls -f title=x'
pre I06-api-backquote deny "$S_OFF" 'echo `gh api repos/o/r/pulls -f title=x`'
pre I07-api-quoted-paren-double deny "$S_OFF" 'gh api -X POST -f title="feat(hooks): x" -f head=feat -f base=main repos/o/r/pulls'
pre I08-api-quoted-paren-single deny "$S_OFF" "gh api -f title='fix(ci): x' repos/o/r/pulls"
pre I09-api-quoted-paren-get none "$S_OFF" 'gh api repos/o/r/pulls/12 -f body="x (y)" -X GET'
pre I10-api-semicolon-boundary none "$S_OFF" 'gh api repos/o/r/pulls/12; echo -X PATCH'
pre I11-api-newline-boundary none "$S_OFF" $'gh api repos/o/r/pulls/12\necho -X PATCH'
pre I12-api-subst-body-before-endpoint deny "$S_OFF" 'gh api -X POST -f title=x -f body="$(cat body.md)" repos/o/r/pulls'
pre I13-api-subst-body-get none "$S_OFF" 'gh api repos/o/r/pulls/12 -f body="$(date)" -X GET'
summary "codex-guard.sh"
