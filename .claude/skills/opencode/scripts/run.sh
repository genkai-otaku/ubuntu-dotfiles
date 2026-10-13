#!/usr/bin/env bash
# Claude Code から OpenCode を非対話で起動して作業を任せ、結果を要約して表示する。
# 指示は標準入力から読む。生の JSONL と stderr は ${TMPDIR:-/tmp}/claude-opencode-logs/ に残す。
# --auto は ask 規則（rm・git commit・git push 等）を自動承認してしまうため、決して付けない。
set -euo pipefail

default_model="opencode-go/claude-haiku-5-5#medium"

usage() {
  cat >&2 <<'EOF'
Usage: run.sh [--dir DIR] [--model PROVIDER/MODEL#VARIANT] [--session ID] [--title TITLE] <<'PROMPT'
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
session=""
title=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dir) need_value "$@"; dir="$2"; shift 2 ;;
    --model|-m) need_value "$@"; model="$2"; shift 2 ;;
    --session|-s) need_value "$@"; session="$2"; shift 2 ;;
    --title) need_value "$@"; title="$2"; shift 2 ;;
    --auto)
      echo "エラー: --auto は受け付けません（ask 規則の操作が自動承認されるため）" >&2
      exit 2
      ;;
    -h|--help) usage ;;
    *) echo "エラー: 不明な引数: $1" >&2; usage ;;
  esac
done

for cmd in opencode jq; do
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

if [ -z "$title" ]; then
  # 最初の空でない行の先頭40文字（jq はコードポイント単位で切るので日本語でも壊れない）
  title="claude-code: $(printf '%s' "$prompt" | jq -Rrs '[splits("\n") | gsub("^\\s+|\\s+$"; "") | select(length > 0)][0] // "" | .[0:40]')"
fi

log_dir="${TMPDIR:-/tmp}/claude-opencode-logs"
mkdir -p "$log_dir"
stamp="$(date +%Y%m%d-%H%M%S)-$$"
log_json="$log_dir/$stamp.jsonl"
log_err="$log_dir/$stamp.stderr.log"

args=(run --format json -m "$model" --title "$title")
if [ -n "$session" ]; then
  args+=(--session "$session")
fi

rc=0
(cd -- "$dir" && opencode "${args[@]}" -- "$prompt" </dev/null >"$log_json" 2>"$log_err") || rc=$?

# head で切ると長いログで jq が SIGPIPE になり pipefail で落ちるので、jq 側で最初の1件に絞る
session_id="$(jq -Rrn 'first(inputs | fromjson? | .sessionID // empty)' "$log_json")"
if [ -z "$session_id" ]; then
  echo "エラー: OpenCode のセッションIDを取得できませんでした（終了コード $rc）" >&2
  echo "--- stderr の末尾（$log_err） ---" >&2
  sed 's/\x1b\[[0-9;]*m//g' "$log_err" | tail -n 20 >&2 || true
  echo "--- JSONL: $log_json ---" >&2
  if [ "$rc" -eq 0 ]; then
    rc=1
  fi
  exit "$rc"
fi

# stderr に出る「permission requested: ...; auto-rejecting」を JSON 側の取りこぼし対策として拾う
rejected_stderr="$(sed 's/\x1b\[[0-9;]*m//g' "$log_err" | grep -E 'auto-rejecting' | sed 's/^[^a-zA-Z]*//' || true)"

echo "## OpenCode 実行結果"
echo
echo "- セッションID: $session_id"
echo "- モデル: $model"
echo "- 作業ディレクトリ: $dir"
echo "- 終了コード: $rc"
echo

jq -Rnr --arg dir "$dir" '
  def short: tostring | gsub("[\r\n\t]+"; " ") | if length > 120 then .[0:117] + "..." else . end;
  def target:
    (.state.input // {}) as $in
    | ($in.command // $in.filePath // $in.file_path // $in.path // $in.pattern // $in.url // $in.description
       // (if ($in | length) > 0 then ($in | tojson) else "" end))
    | tostring
    # 作業ディレクトリ配下のパスは相対にして短くする
    | if startswith($dir + "/") then .[($dir | length) + 1:] else . end;
  [inputs | fromjson? | select(type == "object")] as $ev
  | [$ev[] | select(.type == "tool_use") | .part] as $tools
  | [$tools[] | select(.state.status != "completed")] as $bad
  | [$ev[] | select(.type == "error")] as $errs
  | [$ev[] | select(.type == "step_finish") | .part] as $steps
  | "### 実行したツール（\($tools | length) 件）",
    (if ($tools | length) == 0 then "（なし）"
     else
       # 読む側のトークンを抑えるため末尾20件だけ出す（失敗は下の節に全件出る）
       (if ($tools | length) > 20 then "（先頭 \(($tools | length) - 20) 件は省略）" else empty end),
       ($tools | to_entries | .[-20:][] | "\(.key + 1). [\(.value.state.status // "?")] \(.value.tool // "?"): \(.value | target | short)")
     end),
    "",
    "### 拒否された権限・失敗したツール",
    (if ($bad | length) == 0 and ($errs | length) == 0 then "（なし）"
     else
       ($bad[] | "- [\(.state.status // "?")] \(.tool // "?"): \(. | target | short) — \((.state.error // "") | short)"),
       ($errs[] | "- [error イベント] \((.error // .part // .) | tojson | short)")
     end),
    "",
    "### 最終回答",
    ([$ev[] | select(.type == "text") | .part.text // empty] | if length == 0 then "（テキスト応答なし）" else join("\n\n") end),
    "",
    "### コストとトークン",
    # 最終ステップの step_finish は JSONL に出ないため、この合計は実際より少なめになる
    "- この実行（JSONL の step_finish 合計・最終ステップ分を含まない）: $\(([$steps[] | .cost // 0] | add // 0) * 1000000 | round / 1000000)",
    ( [$steps[] | .tokens // {}] as $t
      | "  - トークン: input \([$t[] | .input // 0] | add // 0) / output \([$t[] | .output // 0] | add // 0) / reasoning \([$t[] | .reasoning // 0] | add // 0) / cache read \([$t[] | .cache.read // 0] | add // 0) / cache write \([$t[] | .cache.write // 0] | add // 0)" )
' "$log_json"

# 正確な値はセッション累計として session export の info から取る（本文は保存しない）
session_total="$(cd -- "$dir" && timeout 60 opencode session export "$session_id" </dev/null 2>/dev/null | jq -r '
  .info | select(.cost != null)
  | "- セッション累計（session export）: $\(.cost * 1000000 | round / 1000000)\n  - トークン: input \(.tokens.input // 0) / output \(.tokens.output // 0) / reasoning \(.tokens.reasoning // 0) / cache read \(.tokens.cache.read // 0) / cache write \(.tokens.cache.write // 0)"
' 2>/dev/null || true)"
if [ -n "$session_total" ]; then
  printf '%s\n' "$session_total"
else
  echo "- セッション累計: 取得できませんでした（opencode session export $session_id で確認）"
fi

if [ -n "$rejected_stderr" ]; then
  echo
  echo "### stderr の権限拒否"
  printf '%s\n' "$rejected_stderr" | sed 's/^/- /'
fi

echo
echo "### ログ"
echo "- JSONL: $log_json"
echo "- stderr: $log_err"
echo
echo "### 続行方法"
printf "bash ~/.claude/skills/opencode/scripts/run.sh --dir %q --session %s <<'EOF'\n...追加の指示...\nEOF\n" "$dir" "$session_id"
if [ "$model" != "$default_model" ]; then
  echo "（同じモデルで続けるなら --model $(printf '%q' "$model") も付ける）"
fi

exit "$rc"
