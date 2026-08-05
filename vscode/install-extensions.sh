#!/bin/bash
# extensions.txt に列挙した拡張機能IDを VSCode / Cursor へインストールする。
# home-manager activation（nix/home.nix）から home-manager switch 時に実行される。
#
# - 冪等：インストール済みの拡張機能はスキップする
# - リストから消してもアンインストールはしない（新規環境に入らなくなるだけ）
# - エディタ本体が未導入（CLIが見つからない）場合はそのエディタをスキップする
# - activation環境のPATHは限定的なため、既知の絶対パス候補を先に探し、
#   見つからなければ command -v にフォールバックする
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$SCRIPT_DIR/extensions.txt"

# 引数の候補（絶対パスまたはコマンド名）から最初に見つかったCLIを返す
find_cli() {
  local candidate
  for candidate in "$@"; do
    case "$candidate" in
      /*)
        if [ -x "$candidate" ]; then
          echo "$candidate"
          return 0
        fi
        ;;
      *)
        if command -v "$candidate" 2>/dev/null; then
          return 0
        fi
        ;;
    esac
  done
  return 1
}

install_for() {
  local name="$1"
  shift
  local cli
  if ! cli="$(find_cli "$@")"; then
    echo "[$name] 本体が見つからないためスキップ"
    return 0
  fi
  local installed
  installed="$("$cli" --list-extensions 2>/dev/null)"
  local ext
  while IFS= read -r ext; do
    [ -z "$ext" ] && continue
    case "$ext" in "#"*) continue ;; esac
    if printf '%s\n' "$installed" | grep -qixF "$ext"; then
      continue
    fi
    echo "[$name] インストール: $ext"
    "$cli" --install-extension "$ext" >/dev/null 2>&1 || echo "[$name] インストール失敗（続行）: $ext"
  done < "$LIST"
}

# VSCode: deb版（/usr/bin/code）→ snap版（/snap/bin/code）→ PATH の順に探す
install_for "VSCode" /usr/bin/code /snap/bin/code code

# Cursor: 手動配置されがちな場所 → PATH の順に探す（AppImage運用でCLI未配置なら自動的にスキップされる）
install_for "Cursor" "$HOME/.local/bin/cursor" /usr/local/bin/cursor cursor
