#!/bin/bash
# 新しいUbuntuマシンを1コマンドでセットアップするブートストラップスクリプト
#
#   curl -fsSL https://raw.githubusercontent.com/seino914/ubuntu-dotfiles/main/bootstrap.sh | bash
#
# やること:
#   1. 前提パッケージ（git・curl・zsh）の確認、なければaptで導入
#   2. Nix の確認（なければ Determinate Systems インストーラーで導入）
#   3. ~/Dev/kaishi を作成してリポジトリをクローン（既にあればそのまま使う）
#   4. flake.nix の username をこのマシンの実際のユーザー名に書き換え
#   5. home-manager を初回適用
#   6. ログインシェルを zsh に変更
#   7. Claude Code CLI を導入（公式インストーラー・自動更新版。あえてNix管理外）
#
# 何度実行しても安全（冪等）。途中で失敗したら原因を解消して再実行すればよい。

set -eu

REPO_URL="https://github.com/seino914/ubuntu-dotfiles.git"
BASE_DIR="$HOME/Dev/kaishi"
DOTFILES_DIR="$BASE_DIR/ubuntu-dotfiles"
CURRENT_USER="$(id -un)"

echo "==> 1/7 前提パッケージ（git・curl・zsh）を確認"
if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v zsh >/dev/null 2>&1; then
  echo "不足しているパッケージをaptで導入します"
  sudo apt-get update && sudo apt-get install -y git curl zsh
fi

echo "==> 2/7 Nix を確認"
if ! command -v nix >/dev/null 2>&1; then
  if [ -x /nix/var/nix/profiles/default/bin/nix ]; then
    # インストール済みだがこのシェルにPATHが通っていないだけ
    export PATH="/nix/var/nix/profiles/default/bin:$PATH"
  else
    echo "Nix をインストールします（Determinate Systems インストーラー）"
    curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
    # インストール直後のこのシェルにPATHを通す
    if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
  fi
fi

echo "==> 3/7 リポジトリを $DOTFILES_DIR へ配置"
mkdir -p "$BASE_DIR"
if [ ! -d "$DOTFILES_DIR/.git" ]; then
  git clone "$REPO_URL" "$DOTFILES_DIR"
else
  echo "既にクローン済みのためそのまま使います"
fi
cd "$DOTFILES_DIR"

echo "==> 4/7 flake.nix の username をこのマシンのユーザー名 ($CURRENT_USER) に合わせる"
sed -i -E "s|username = \"[^\"]+\";|username = \"$CURRENT_USER\";|" flake.nix
if ! git diff --quiet flake.nix; then
  echo "flake.nix の username を書き換えました。あとでこの差分をコミットしてください"
fi

echo "==> 5/7 home-manager を適用します（sudo不要）"
nix run home-manager/master -- switch --flake ".#ubuntu" -b hm-backup

echo "==> 6/7 ログインシェルを zsh に変更"
if [ "$(basename "$SHELL")" != "zsh" ]; then
  echo "パスワードを求められる場合があります"
  chsh -s "$(command -v zsh)"
else
  echo "既に zsh のためスキップします"
fi

echo "==> 7/7 Claude Code CLI を確認"
if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
  echo "Claude Code をインストールします（公式インストーラー・自動更新あり）"
  curl -fsSL https://claude.ai/install.sh | bash
else
  echo "既にインストール済みのためスキップします"
fi

echo ""
echo "セットアップ完了！"
echo "手動で必要な残作業（~/.claude/.line-env の配置、Docker Engineの導入など）は"
echo "nix/README.md を参照してください。"
