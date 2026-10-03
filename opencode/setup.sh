#!/bin/bash
# OpenCode公式インストーラーでCLIを導入する（冪等）。
# PATHは zsh/.zshrc が ~/.opencode/bin を設定するため、installerによる設定ファイル編集は無効化する。

set -euo pipefail

if command -v opencode >/dev/null 2>&1 || [ -x "$HOME/.opencode/bin/opencode" ]; then
  echo "OpenCode は既にインストール済みのためスキップします"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl がないためOpenCodeをインストールできません" >&2
  exit 1
fi

echo "OpenCodeを公式インストーラーでインストールします"
curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
