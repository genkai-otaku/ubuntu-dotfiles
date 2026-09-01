#!/usr/bin/env bash
# Codex フックから Claude 側の共有スクリプトを呼ぶ薄いラッパー。
# Codex は ~/.claude/settings.json を読まないため、hooks.json からここを経由する。
# CODEX_HOOK=1 で pr-mode.sh / notify.sh が Codex 向けの入出力に切り替える。

export CODEX_HOOK=1
hook="${1:-}"
case "$hook" in
  pr-mode | notify) ;;
  *) exit 0 ;;
esac
exec bash "$HOME/.claude/hooks/${hook}.sh"
