#!/usr/bin/env bash
# Claude Code から Codex CLI を非対話（codex exec）で起動して作業を任せ、結果を要約して表示する。
# 指示は標準入力から読む。生の JSONL・stderr・最終メッセージは ${TMPDIR:-/tmp}/claude-codex-logs/ に残す。
# サンドボックスは workspace-write に固定し、承認・サンドボックスを外すオプションは受け付けない。
set -euo pipefail

default_model="gpt-6.1-sol"
default_effort="medium"

usage() {
  cat >&2 <<'EOF'
Usage: run.sh [--dir DIR] [--model MODEL] [--effort EFFORT] [--session ID] <<'PROMPT'
...指示...
PROMPT
EOF
  exit 2
}

need_value() {
  if [ "$#" -lt 2 ] || [ -z "$2" ]; then
    echo "エラー: $1 には値が必要です" >&2
    usage
  fi
}

dir="$PWD"
model="$default_model"
effort="$default_effort"
session=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dir) need_value "$@"; dir="$2"; shift 2 ;;
    --model|-m) need_value "$@"; model="$2"; shift 2 ;;
    --effort) need_value "$@"; effort="$2"; shift 2 ;;
    --session|-s) need_value "$@"; session="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "エラー: 不明な引数: $1" >&2; usage ;;
  esac
done

for cmd in codex jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "エラー: $cmd が見つかりません" >&2
    exit 127
  fi
done

if [ ! -d "$dir" ] || ! dir="$(cd -- "$dir" && pwd -P)"; then
  echo "エラー: 作業ディレクトリが見つかりません: $dir" >&2
  exit 2
fi

if [ -t 0 ]; then
  echo "エラー: 指示を標準入力（heredoc）で渡してください" >&2
  usage
fi
prompt="$(cat)"
if [ -z "${prompt//[[:space:]]/}" ]; then
  echo "エラー: 指示が空です" >&2
  exit 2
fi

log_dir="${TMPDIR:-/tmp}/claude-codex-logs"
mkdir -p "$log_dir"
stamp="$(date +%Y%m%d-%H%M%S)-$$"
log_json="$log_dir/$stamp.jsonl"
log_err="$log_dir/$stamp.stderr.log"
log_last="$log_dir/$stamp.last.txt"

common=(-m "$model" -c "model_reasoning_effort=\"$effort\"" -c 'sandbox_mode="workspace-write"' --json -o "$log_last")

# 指示は stdin（-）で渡す。resume には -C が無いので cd して実行する
rc=0
if [ -n "$session" ]; then
  (cd -- "$dir" && printf '%s' "$prompt" | codex exec resume "${common[@]}" "$session" - >"$log_json" 2>"$log_err") || rc=$?
else
  (cd -- "$dir" && printf '%s' "$prompt" | codex exec "${common[@]}" -C "$dir" - >"$log_json" 2>"$log_err") || rc=$?
fi

# 新規は thread.started から取る。resume で出ない場合は渡した ID を使う
thread_id="$(jq -Rrn 'first(inputs | fromjson? | select(.type == "thread.started") | .thread_id // empty)' "$log_json")"
thread_id="${thread_id:-$session}"
if [ -z "$thread_id" ]; then
  echo "エラー: Codex のセッションIDを取得できませんでした（終了コード $rc）" >&2
  echo "--- stderr の末尾（$log_err） ---" >&2
  tail -n 20 "$log_err" >&2 || true
  echo "--- JSONL: $log_json ---" >&2
  if [ "$rc" -eq 0 ]; then
    rc=1
  fi
  exit "$rc"
fi

echo "## Codex 実行結果"
echo
echo "- セッションID: $thread_id"
echo "- モデル: $model（effort: $effort）"
echo "- 作業ディレクトリ: $dir"
echo "- 終了コード: $rc"
echo

jq -Rnr --arg dir "$dir" '
  def short: tostring | gsub("[\r\n\t]+"; " ") | if length > 120 then .[0:117] + "..." else . end;
  # 「/usr/bin/zsh -lc '\''...'\''」のラッパーを外して本体だけ見せる
  def unwrap: tostring | (capture("^\\S+ -lc (?<q>['\''\"])(?<c>.*)\\k<q>$"; "p").c // .);
  # 失敗の理由は末尾に出ることが多いので、出力は末尾を見せる
  def tail: tostring | gsub("[\r\n\t]+"; " ") | if length > 120 then "..." + .[-117:] else . end;
  def text: if type == "string" then . else (.message // .error.message // .error // .) | if type == "string" then . else tojson end end;
  def rel: tostring | if startswith($dir + "/") then .[($dir | length) + 1:] else . end;
  [inputs | fromjson? | select(type == "object")] as $ev
  | [$ev[] | select(.type == "item.completed") | .item] as $items
  | [$items[] | select(.type == "command_execution")] as $cmds
  | [$items[] | select(.type == "file_change") | (.changes // [])[] | "\(.kind // "?") \(.path | rel)"] as $files
  | [$cmds[] | select(.status != "completed" or ((.exit_code // 0) != 0))] as $bad
  | [([$items[] | select(.type == "error")] + [$ev[] | select(.type == "error" or .type == "turn.failed")])[] | text] | unique as $errs
  | [$ev[] | select(.type == "turn.completed") | .usage] as $usage
  | "### 実行したコマンド（\($cmds | length) 件）",
    (if ($cmds | length) == 0 then "（なし）"
     else
       # 読む側のトークンを抑えるため末尾20件だけ出す（失敗は下の節に全件出る）
       (if ($cmds | length) > 20 then "（先頭 \(($cmds | length) - 20) 件は省略）" else empty end),
       ($cmds | to_entries | .[-20:][] | "\(.key + 1). [\(.value.exit_code // .value.status)] \(.value.command | unwrap | short)")
     end),
    (if ($files | length) > 0 then "", "### ファイル変更", ($files | unique[] | "- \(.)") else empty end),
    "",
    "### 失敗したコマンド・エラー",
    (if ($bad | length) == 0 and ($errs | length) == 0 then "（なし）"
     else
       ($bad[] | "- [\(.exit_code // .status)] \(.command | unwrap | short) — \((.aggregated_output // "") | tail)"),
       ($errs[] | "- \(short)")
     end),
    "",
    "### トークン",
    "- input \([$usage[] | .input_tokens // 0] | add // 0)（cached \([$usage[] | .cached_input_tokens // 0] | add // 0)） / output \([$usage[] | .output_tokens // 0] | add // 0)（reasoning \([$usage[] | .reasoning_output_tokens // 0] | add // 0)）"
' "$log_json"

echo
echo "### 最終回答"
if [ -s "$log_last" ]; then
  cat "$log_last"
  echo
else
  echo "（なし）"
fi

echo
echo "### ログ"
echo "- JSONL: $log_json"
echo "- stderr: $log_err"
echo
echo "### 続行方法"
printf "bash ~/.claude/skills/codex/scripts/run.sh --dir %q --session %s <<'EOF'\n...追加の指示...\nEOF\n" "$dir" "$thread_id"

exit "$rc"
