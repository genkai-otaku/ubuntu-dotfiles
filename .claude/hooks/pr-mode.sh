#!/bin/bash

# /pr モード管理フック（Claude Code / Grok CLI）
# ユーザーが /pr を実行しているターンの間だけ、git commit / git push /
# gh pr create（別名 gh pr new）/ gh pr edit を許可する。
# それ以外の場面では同コマンドを実行前に拒否する。
# gh pr merge は常に ask。force push は /pr 中でも deny。
# /pr 中でも、サブエージェントからの git 書き込み（入力に agent_id がある）は deny、
# コミットされる差分に既知のトークン形式があるコミット（lib/scan-secrets.sh が検査）は ask。
#
# Claude Code:
# - UserPromptExpansion: command_name が "pr" ならフラグ作成、別コマンドなら削除
#   （UserPromptSubmit の prompt は展開後のスキル本文なので、スラッシュコマンド名の
#     判定は Expansion の command_name が正）
# - UserPromptSubmit: プロンプトが /pr（またはその展開本文）でなければフラグを削除。
#   中断などで Stop が走らず残った残骸フラグをここで確実に消す
#   （UserPromptExpansion との発火順は保証されないが、/pr のときは Expansion 側が
#     後から touch し直すので成立する）
# - PreToolUse(Bash): フラグが無ければ、コミット・push・PR作成を含むコマンドを
#   permissionDecision=deny で拒否する。force push とフラグ改ざんは /pr 中でも deny。
#   PreToolUse は permission mode（auto / acceptEdits / bypassPermissions）や allow
#   ルールに関係なく毎回発火し、deny は必ず効くため、最終防衛層はここに置く
# - PermissionRequest(Bash): フラグがあれば、対象コマンドを decision.behavior=allow で
#   自動承認する（PreToolUse の allow では permissions.ask を上書きできないため、
#   ask ダイアログの代替はこのイベントで行う）
# - Stop: ターン終了時にフラグ削除
#
# Grok:
# - UserPromptExpansion / PermissionRequest は無い
# - stdin は camelCase、イベント名は GROK_HOOK_EVENT、ツール名は run_terminal_command
#   （matcher "Bash" はエイリアスで当たる。スクリプト側でも両方見る）
# - UserPromptSubmit: 先頭 /pr、番兵 <!-- pr-mode-enable -->、または SKILL.md の H1
#   でフラグ作成。それ以外の非空 prompt ではフラグ削除（空の auto-wake では触らない）
# - PreToolUse: フラグが無ければ対象コマンドを deny（always-approve でも止まる）。
#   /pr 中でも force push は deny。自動承認条件を満たさない git 書き込みは ask
#   （hook の ask は always-approve でも確認プロンプトになる）
# - Stop: フラグ削除
#
# 自動承認の条件（すべて満たすときだけ allow。満たさなければ何も出力せず通常の
# 確認ダイアログに落とす。拒否はしない）:
# - コマンド文字列が git commit / git push / gh pr create で始まる
# - 引用符の中身と HEREDOC 本文を除いた上で、複合コマンド・コマンド置換・
#   リダイレクトを含まない（&& || ; | & $( ` <( >( > <。2>&1 は許容）。
#   除去は lib/strip-shell.awk（引用符の種別を追跡する状態機械）で行う。
#   HEREDOC の 2 行目以降は ")" で始まる行だけ許す（"$(cat <<'EOF' … EOF\n)" の定型）
# - git push: force 系（--force* / -f を含む短縮群 / +refspec）、削除系（--delete /
#   -d / :branch）、--mirror、--no-verify、main / master への push を含まない。
#   さらに cwd の現在ブランチが main / master なら落とす
# - git commit: --no-verify / -n を含む短縮群 / --amend を含まない
# - gh pr create: 別リポジトリ宛（-R / --repo）を含まない
# - 引用符を含むトークン（"--force" / --for"ce" / -"f" / "main" / ma'in'）は、引用符を取り除いた形が
#   オプション（- で始まる）か main / master 宛なら落とす（引用符の中身は除去されるので、
#   引用符を残した版のトークンごとに見る。main / master の検査は git push / git commit だけで、
#   gh pr の --base "main" は落とさない）。push の引数に変数（$BRANCH）を含まない
# - 除去処理が失敗した・引用符が閉じていない場合は複合扱い（安全側）。
#   拒否判定側は逆に、除去に失敗したら生文字列で判定する（fail-open にしない）
#
# 拒否判定（フラグ無し）は、除去後の文字列に対する正規表現で行う。
# git [-C dir] [-c k=v] commit|push、/usr/bin/git、\git（エイリアス回避）、command git、env X=1 git、
# "git push;" / "(git push)" のような区切り直前の形を捕捉し、引用符の中のリテラル（git log --grep "git commit" 等）
# は拒否しない。gh api は /pulls への書き込み（POST / -f / --input）と GraphQL の createPullRequest
# （gh api / graphql の文脈にあるものだけ）を対象にし、GET（PR 一覧・コメント取得）は拒否しない。
# session_id の無い PreToolUse / PermissionRequest は /pr 中と確認できないので拒否側で扱う（fail-open にしない）。
# bash -c / sh -c / eval で引用符の中を実行する場合だけ生文字列の部分一致も併用する。
# 既知の抜け道: git alias 経由（git -c alias.x=commit x）は捕捉しない（CLAUDE.md の指示で抑止）。
#
# 制約:
# - フラグは session_id 単位。/pr の git 操作をサブエージェントに委譲すると
#   別セッション扱いで拒否される（SKILL.md で「メインが直接実行」と明記）
# - Stop でフラグが消えるため、/pr の途中でターンを終えて質問すると次ターンは拒否
#   される（SKILL.md で AskUserQuestion を使う旨を明記）
# - jq が無い・入力 JSON が壊れている場合は何もせず exit 0（~/.claude/pr-mode.log に記録）。
#   どのイベントでも exit 0 固定（Stop / UserPromptSubmit での exit 2 は処理を止めるため）
# - 判定 JSON は Claude 形式（hookSpecificOutput.permissionDecision）。Grok も同じキーを読む

LOG="$HOME/.claude/pr-mode.log"
SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
STRIP_AWK="$(dirname "$SELF")/lib/strip-shell.awk"

logmsg() { printf '%s %s\n' "$(date +%FT%T)" "$*" >>"$LOG" 2>/dev/null; }

if ! command -v jq >/dev/null 2>&1; then
  logmsg "jq が見つからないため pr-mode は無効です（PATH=${PATH}）"
  exit 0
fi

input=$(cat)
if ! event=$(printf '%s' "$input" | jq -r '.hook_event_name // .hookEventName // empty' 2>/dev/null); then
  logmsg "入力 JSON を解釈できません"
  exit 0
fi
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

# JSON の session を優先する。GROK_SESSION_ID は JSON に無いときだけ使う
# （テストや他セッションの環境変数でフラグ経路が差し替わらないように）
session=$(printf '%s' "$input" | jq -r '.session_id // .sessionId // empty')
if [ -z "$session" ] && [ -n "${GROK_HOOK_EVENT:-}" ]; then
  session="${GROK_SESSION_ID:-}"
fi
if [ -z "$session" ]; then
  case "$event" in
    PreToolUse | PermissionRequest)
      # フラグの所在が分からない = /pr 中と確認できないので、フラグ無し（拒否側）として扱う
      logmsg "session_id が無い ${event} を /pr 外として扱いました"
      flag="" ;;
    *)
      logmsg "session_id が無いイベント（${event}）を無視しました"
      exit 0 ;;
  esac
else
  flag="${TMPDIR:-/tmp}/claude-pr-mode-${session}"
fi

# Git 書き込みの判定は Codex と同じ関数を使う。
source "$(dirname "$SELF")/lib/git-write.sh"

# コミットされる差分に既知のトークン形式があるか調べ、「ファイル名（形式名）」の一覧を返す
# （lib/scan-secrets.sh に委譲。一致が無ければ空）。-a / -am のときは git diff HEAD を見る。
# スクリプトが無い・cwd が分からないときは空を返す（この検査は多層防御の一層で、網羅は追わない）
secret_hits() {
  local raw="$1" scan cwd mode=staged
  scan="$(dirname "$SELF")/lib/scan-secrets.sh"
  [ -f "$scan" ] || return 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
  [ -n "$cwd" ] || return 0
  printf '%s\n' "$raw" | grep -Eq -- '(^|[[:space:]])(-[A-Za-z]*a[A-Za-z]*|--all)([[:space:]]|$)' && mode=all
  # 複数件は「、」で連結する（paste -d は区切りをバイト単位で扱い、全角文字では壊れる）
  bash "$scan" "$cwd" "$mode" 2>/dev/null | awk 'NR > 1 { printf "、" } { printf "%s", $0 } END { if (NR) print "" }'
}

# /pr 中の自動承認対象か（引数: 生コマンド）。対象なら 0
is_auto_approvable() {
  local raw="$1" s rest flat
  case "$raw" in
    "git push" | "git push "* | "git commit "* \
    | "gh pr create" | "gh pr create "* | "gh pr new" | "gh pr new "* | "gh pr edit "*) ;;
    *) return 1 ;;
  esac

  s=$(strip_cmd "$raw")
  # 許容する定型だけ判定前に取り除く: "$(cat <<'EOF'" と 2>&1 系
  s=$(printf '%s\n' "$s" | sed -E "s/\\\$\\(cat[[:space:]]+<<-?[[:space:]]*['\"]?[A-Za-z_][A-Za-z0-9_-]*['\"]?//; s/[0-9]*>&[0-9]+//g; s/<<-?[[:space:]]*['\"]?[A-Za-z_][A-Za-z0-9_-]*['\"]?//")
  # 2 行目以降は ")" で始まる行だけ許す（"$(cat <<'EOF' … EOF\n)" の閉じ行）
  rest=$(printf '%s\n' "$s" | sed -E '1d; /^[[:space:]]*(\).*)?$/d' | grep -c .)
  [ "$rest" -gt 0 ] && return 1
  case "$s" in
    *'&&'* | *'||'* | *';'* | *'|'* | *'&'* | *'$('* | *'`'* | *'<('* | *'>('* | *'>'* | *'<'*) return 1 ;;
  esac
  # オプションの検査は閉じ行 ")" 以降も含めた全行に対して行う
  # （閉じ行に --amend や --force を置く抜け道を塞ぐ）
  flat=$(printf '%s' "$s" | tr '\n' ' ')
  # 引用符の中身は除去済みなので、引用符付き・引用符で割ったオプション（"--force" / --for"ce" / -"f"）と
  # 引用された main / master（"main" / ma'in' / "HEAD:main"）は引用符を残した版をトークンごとに見る:
  # 引用符を含むトークンは、引用符を取り除いた形がオプション（- で始まる）か main / master 宛なら落とす
  # （引用符の中の空白は \001 なので、"docs: --amend の説明" のようなメッセージは 1 トークンのまま）。
  # main / master 宛の検査は git push / git commit だけに掛ける（gh pr create / new / edit の
  # --base "main" はマージ先の指定で、デフォルトブランチへの書き込みではない）
  local kq tok nq check_main=1
  case "$raw" in "gh pr "*) check_main=0 ;; esac
  kq=$(printf '%s\n' "$raw" | awk -v keepq=1 -f "$STRIP_AWK" 2>/dev/null | tr '\n' ' ')
  set -f
  for tok in $kq; do
    nq=${tok//[\"\']/}
    [ "$tok" = "$nq" ] && continue
    case "$nq" in -*) set +f; return 1 ;; esac
    [ "$check_main" -eq 1 ] && printf '%s\n' "$nq" | grep -Eq -- '(^|[:/])(main|master)$' && { set +f; return 1; }
  done
  set +f
  case "$raw" in
    "git push"*)
      # 変数入りの refspec（$BRANCH）は宛先を特定できないので落とす
      case "$raw" in *'$'*) return 1 ;; esac
      case "$flat" in *--force* | *--mirror* | *--delete* | *--no-verify* | *--prune* | *--all* | *--tags*) return 1 ;; esac
      # -f/-d/-n を含む短縮オプション群、+refspec、:refspec（削除）、main/master 宛
      # （HEAD:main / feat:refs/heads/main のように refspec の末尾が main/master の形も含む）
      printf '%s\n' "$flat" | grep -Eq -- '(^|[[:space:]])-[A-Za-z]*[fdn][A-Za-z]*([[:space:]]|$)|(^|[[:space:]])\+[^[:space:]]|(^|[[:space:]]):[^[:space:]]|(^|[[:space:]:/])(main|master)([[:space:]]|$)' && return 1
      local cwd branch
      cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
      if [ -n "$cwd" ]; then
        branch=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null)
        case "$branch" in main | master) return 1 ;; esac
      fi
      ;;
    "git commit"*)
      case "$flat" in *--no-verify* | *--amend*) return 1 ;; esac
      printf '%s\n' "$flat" | grep -Eq -- '(^|[[:space:]])-[A-Za-z]*n[A-Za-z]*([[:space:]]|$)' && return 1
      # コミットされる差分に既知のトークン形式があれば自動承認しない（確認ダイアログに落とす）
      [ -n "$(secret_hits "$raw")" ] && return 1
      ;;
    "gh pr create"* | "gh pr new"* | "gh pr edit"*)
      # 別リポジトリ宛（-R / --repo）は /pr の対象外なので確認ダイアログに落とす
      printf '%s\n' "$flat" | grep -Eq -- '(^|[[:space:]])(-R|--repo)([[:space:]=]|$)' && return 1
      ;;
  esac
  return 0
}

emit_pre_deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
}
emit_pre_ask() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
}

is_shell_tool() {
  case "$1" in Bash|run_terminal_command) return 0 ;; *) return 1 ;; esac
}

case "$event" in
  UserPromptExpansion)
    cmd_name=$(printf '%s' "$input" | jq -r '.command_name // .commandName // empty')
    if [ "$cmd_name" = "pr" ]; then
      touch "$flag"
    else
      rm -f "$flag"
    fi
    ;;
  UserPromptSubmit)
    prompt=$(printf '%s' "$input" | jq -r '.prompt // .user_prompt // .userPrompt // empty')
    subagent=$(printf '%s' "$input" | jq -r '.subagentType // .subagent_type // empty')
    # サブエージェントの submit で親のフラグを消さない
    if [ -n "$subagent" ] && [ "$subagent" != "null" ]; then
      exit 0
    fi
    # /pr の展開本文は SKILL.md の見出し（最初の "# " 行）で見分ける。見出しは SKILL.md から実行時に読むので
    # 改名しても追従する。SKILL.md が読めなければ（= /pr 自体が存在しない）展開本文とは判定せずフラグを消す（fail-closed）
    pr_h1=$(grep -m1 '^# ' "$(dirname "$SELF")/../skills/pr/SKILL.md" 2>/dev/null)
    is_pr_prompt=0
    case "$prompt" in
      "/pr" | "/pr "* | "/pr"$'\n'*) is_pr_prompt=1 ;;
      *'<!-- pr-mode-enable -->'*) is_pr_prompt=1 ;;
      *) [ -n "$pr_h1" ] && [[ "$prompt" == *"$pr_h1"* ]] && is_pr_prompt=1 ;;
    esac
    if [ "$is_pr_prompt" -eq 1 ]; then
      # Grok は Expansion が無いので Submit で立てる。Claude は Expansion が touch 済みでも冪等
      touch "$flag"
    elif [ -n "${GROK_HOOK_EVENT:-}" ]; then
      # prompt が空の auto-wake では触らない
      [ -n "$prompt" ] && rm -f "$flag"
    else
      rm -f "$flag"
    fi
    ;;
  PreToolUse)
    tool=$(printf '%s' "$input" | jq -r '.tool_name // .toolName // empty')
    is_shell_tool "$tool" || exit 0
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // .toolInput.command // empty')
    [ -n "$cmd" ] || exit 0
    # フラグはフックだけが作る。エージェントが touch / リダイレクトで迂回するのを止める。
    # git commit / gh pr create の本文にフラグ名が出るだけでは deny しない
    case "$cmd" in
      *claude-pr-mode-*)
        case "$cmd" in
          *"git commit"*|*"git push"*|*"gh pr create"*|*"gh pr new"*|*"gh pr edit"*|*"gh pr merge"*) ;;
          *)
            emit_pre_deny 'pr-mode フラグはフック以外が作成・変更してはならない'
            exit 0
            ;;
        esac
        ;;
    esac
    if is_force_push "$cmd"; then
      emit_pre_deny 'force push は禁止されています'
      exit 0
    fi
    if [ -f "$flag" ]; then
      # サブエージェントからの git 書き込みは /pr 中でも拒否する（フラグはセッション単位で、
      # 同じ session_id で届くサブエージェントの実行まで自動承認してしまわないように）
      agent=$(printf '%s' "$input" | jq -r '.agent_id // .agentId // empty')
      if [ -n "$agent" ] && is_git_write "$cmd" "$(stripped_or_raw "$cmd")"; then
        emit_pre_deny 'コミット・push・PR の作成と更新はメインセッションが直接実行してください（サブエージェントからは実行できません）。'
        exit 0
      fi
      # コミット直前に、コミットされる差分の秘密情報を検査する（一致があれば自動承認しない）
      case "$cmd" in
        "git commit"*)
          hits=$(secret_hits "$cmd")
          if [ -n "$hits" ]; then
            emit_pre_ask "コミットされる差分に秘密情報の形式が見つかりました: ${hits}。該当ファイルを add から外すか、ユーザーに確認してください。"
            exit 0
          fi
          ;;
      esac
      # /pr 中: 自動承認条件を満たすものだけ素通し。満たさない git 書き込みは
      # Claude は PermissionRequest に委ね、Grok（PermissionRequest 無し）は ask
      if [ -n "${GROK_HOOK_EVENT:-}" ] && is_git_write "$cmd" "$(stripped_or_raw "$cmd")" && ! is_auto_approvable "$cmd"; then
        emit_pre_ask 'この git 操作は /pr の自動許可対象外です。force・amend・デフォルトブランチ宛・複合コマンドではないか確認してください'
      fi
      exit 0
    fi
    if is_git_write "$cmd" "$(stripped_or_raw "$cmd")"; then
      emit_pre_deny 'コミット・push・PR作成はユーザーが /pr を実行しているターンでのみ許可されます。自分では実行せず、ユーザーに /pr の実行を依頼してください。'
    fi
    ;;
  PermissionRequest)
    tool=$(printf '%s' "$input" | jq -r '.tool_name // .toolName // empty')
    is_shell_tool "$tool" || exit 0
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // .toolInput.command // empty')
    if [ -f "$flag" ]; then
      if is_auto_approvable "$cmd"; then
        jq -cn '{hookSpecificOutput:{hookEventName:"PermissionRequest",decision:{behavior:"allow"}}}'
      fi
    elif is_git_write "$cmd" "$(stripped_or_raw "$cmd")"; then
      # 通常は PreToolUse で止まる。PreToolUse が無効な環境向けの二重化
      jq -cn '{hookSpecificOutput:{hookEventName:"PermissionRequest",decision:{behavior:"deny",message:"コミット・push・PR作成はユーザーが /pr を実行しているターンでのみ許可されます。ユーザーに /pr の実行を依頼してください。"}}}'
    fi
    ;;
  Stop)
    rm -f "$flag"
    ;;
esac

exit 0
