#!/bin/bash
# Grok CLI 相当の入出力（camelCase・GROK_HOOK_EVENT・run_terminal_command）で
# pr-mode / guard-destructive / validate-claude-config が動くことを固定する
set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
PR="$HOOKS_DIR/pr-mode.sh"
GD="$HOOKS_DIR/guard-destructive.sh"
VAL="$HOOKS_DIR/validate-claude-config.sh"
S_ON=test-grok-on-$$
S_OFF=test-grok-off-$$
IN="$HOME/Dev/kaishi/ubuntu-dotfiles"
cleanup() { rm -f "$T"/claude-pr-mode-test-grok-*-$$; rm -rf "$T/claude-grok-validate.$$"; }
trap cleanup EXIT
cleanup

gpre() { report "$1" "$2" "$(decision_of "$(run_hook_grok "$PR" pre_tool_use "$3" "$4")")" "$4"; }

echo "# Grok pr-mode: UserPromptSubmit でフラグ作成 / 削除"
run_hook_grok "$PR" user_prompt_submit "$S_ON" "" "/pr" >/dev/null
[ -f "$T/claude-pr-mode-$S_ON" ] && r=yes || r=no
report G01-submit-/pr yes "$r" ""

run_hook_grok "$PR" user_prompt_submit "$S_ON" "" $'# PR作成\n\n<!-- pr-mode-enable -->\n現在の作業内容をコミットし…' >/dev/null
[ -f "$T/claude-pr-mode-$S_ON" ] && r=yes || r=no
report G02-submit-sentinel yes "$r" ""

run_hook_grok "$PR" user_prompt_submit "$S_ON" "" "別の作業をして" >/dev/null
[ -f "$T/claude-pr-mode-$S_ON" ] && r=yes || r=no
report G03-submit-other no "$r" ""

run_hook_grok "$PR" user_prompt_submit "$S_ON" "" "/pr" >/dev/null
run_hook_grok "$PR" user_prompt_submit "$S_ON" "" "" >/dev/null
[ -f "$T/claude-pr-mode-$S_ON" ] && r=yes || r=no
report G04-empty-autowake yes "$r" ""

echo "# Grok pr-mode: PreToolUse deny / allow / force"
gpre G10-commit-off deny "$S_OFF" 'git commit -m x'
gpre G11-push-off deny "$S_OFF" 'git push -u origin feat/x'
gpre G12-create-off deny "$S_OFF" 'gh pr create --fill'
gpre G13-status-off none "$S_OFF" 'git status'
gpre G14-commit-on none "$S_ON" 'git commit -m x'
gpre G15-force-on deny "$S_ON" 'git push --force origin feat'
gpre G16-force-f deny "$S_ON" 'git push -f origin feat'
gpre G17-amend-on ask "$S_ON" 'git commit --amend --no-edit'
gpre G18-camel-tool deny "$S_OFF" 'git commit -m x'

echo "# Grok guard-destructive: camelCase + run_terminal_command"
gd() {
  report "$1" "$2" "$(decision_of "$(run_hook_grok "$GD" pre_tool_use test-gd "$3" "" "$IN")")" "$3"
}
gd G20-rm-root deny 'rm -rf /'
gd G21-rm-home deny 'rm -rf ~'
gd G22-rm-claude deny 'rm -rf ~/.claude'
gd G23-reset-hard ask 'git reset --hard HEAD~1'
gd G24-rm-dist none 'rm -rf dist'
gd G25-rm-outside deny 'rm -rf ~/Documents/a'

echo "# Grok validate-claude-config: camelCase toolInput.file_path"
W="$T/claude-grok-validate.$$"
mkdir -p "$W/.claude/hooks"
cp "$VAL" "$W/.claude/hooks/validate-claude-config.sh"
H="$W/.claude/hooks/validate-claude-config.sh"
printf '{"a":1}' > "$W/.claude/ok.json"
out=$(jq -cn --arg f "$W/.claude/ok.json" \
  '{hookEventName:"post_tool_use",sessionId:"t",toolName:"search_replace",toolInput:{file_path:$f}}' \
  | GROK_HOOK_EVENT=post_tool_use bash "$H" 2>&1); rc=$?
report G30-json-ok 0 "$rc" "$out"
printf '{"a":1,}' > "$W/.claude/bad.json"
out=$(jq -cn --arg f "$W/.claude/bad.json" \
  '{hookEventName:"post_tool_use",sessionId:"t",toolName:"write",toolInput:{file_path:$f}}' \
  | GROK_HOOK_EVENT=post_tool_use bash "$H" 2>&1); rc=$?
report G31-json-bad 2 "$rc" "$out"

run_hook_grok "$PR" stop "$S_ON" >/dev/null
[ -f "$T/claude-pr-mode-$S_ON" ] && r=yes || r=no
report G40-stop no "$r" ""

summary "grok-compat"
