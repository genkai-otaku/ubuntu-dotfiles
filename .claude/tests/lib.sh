# テスト共通ヘルパー（bash のみで動く。bats 等は不要）
# 使い方: source "$(dirname "$0")/lib.sh" のあとで check / payload / run を使う
# 環境変数 HOOKS_DIR でテスト対象の hooks ディレクトリを差し替えられる（既定はリポジトリの .claude/hooks）

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="${HOOKS_DIR:-$(cd "$TESTS_DIR/../hooks" && pwd)}"
# 親の Grok セッション環境がテストのフラグ経路を汚染しないようにする。
# Grok 互換テストは run_hook_grok がコマンドごとに付け直す
unset GROK_HOOK_EVENT GROK_SESSION_ID GROK_HOOK_NAME
# ホストの TMPDIR（未設定や /tmp）に依存させない。/tmp 全体を許可領域にすると
# R44（rm -rf /tmp/other は deny）が崩れる
export TMPDIR="${TMPDIR:-/tmp}/claude-tests-$$"
mkdir -p "$TMPDIR"
T="$TMPDIR"
PASS=0
FAIL=0
FAILED_CASES=""

payload() { # event session cmd [command_name] [prompt] [cwd]
  jq -cn --arg e "$1" --arg s "$2" --arg c "${3-}" --arg n "${4-}" --arg p "${5-}" --arg d "${6-/tmp}" \
    '{hook_event_name:$e, session_id:$s, cwd:$d, tool_name:"Bash", tool_input:{command:$c}}
     + (if $n != "" then {command_name:$n} else {} end)
     + (if $p != "" then {prompt:$p} else {} end)'
}

run_hook() { # hook-file event session cmd [command_name] [prompt] [cwd]
  local hook="$1"; shift
  payload "$@" | bash "$hook" 2>/dev/null
}

# 出力 JSON から判定結果を取り出す: allow / deny / ask / none
# Claude 形式（permissionDecision / behavior）と Grok 形式（top-level decision）の両方を見る
decision_of() {
  local out="$1"
  case "$out" in
    *'"behavior":"allow"'* | *'"permissionDecision":"allow"'* | *'"decision":"allow"'*) echo allow ;;
    *'"behavior":"deny"'* | *'"permissionDecision":"deny"'* | *'"decision":"deny"'*) echo deny ;;
    *'"permissionDecision":"ask"'* | *'"decision":"ask"'*) echo ask ;;
    *) echo none ;;
  esac
}

# Grok CLI 相当の camelCase 入力
payload_grok() { # event session cmd [prompt] [cwd] [tool]
  local tool="${6:-run_terminal_command}"
  jq -cn --arg e "$1" --arg s "$2" --arg c "${3-}" --arg p "${4-}" --arg d "${5-/tmp}" --arg t "$tool" \
    '{hookEventName:$e, sessionId:$s, cwd:$d, toolName:$t, toolInput:{command:$c}}
     + (if $p != "" then {prompt:$p} else {} end)'
}

run_hook_grok() { # hook-file event session cmd [prompt] [cwd] [tool]
  local hook="$1"; shift
  local ev="$1"
  # 環境変数はパイプライン右側（フック）に付ける。左側だけだと bash は子に渡さない
  payload_grok "$@" | GROK_HOOK_EVENT="$ev" GROK_SESSION_ID="$2" bash "$hook" 2>/dev/null
}

report() { # label expected got detail
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES="$FAILED_CASES\n  NG [$1] expect=$2 got=$3 :: $(printf '%s' "$4" | tr '\n' '\001' | sed 's/\001/⏎/g' | cut -c1-120)"
  fi
}

# 各テストの末尾で必ず 1 回呼ぶ（呼び忘れ・重複は run.sh が summary 行の数で検出する）
summary() {
  local name="$1"
  if [ "$FAIL" -eq 0 ]; then
    echo "  ✓ $name: $PASS 件すべて通過"
    return 0
  fi
  echo "  ✗ $name: $FAIL 件失敗 / $PASS 件通過"
  printf '%b\n' "$FAILED_CASES"
  return 1
}
