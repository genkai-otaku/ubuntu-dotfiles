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
#   5. home-manager を初回適用（tmux と SSH 時の自動 attach を含む）
#   6. ログインシェルを zsh に変更
#   7. Oh My Zsh と Powerlevel10k を導入（あえてNix管理外。git clone直で導入）
#   8. Claude Code CLI を導入（公式インストーラー・自動更新版。あえてNix管理外）
#   9. ibus-mozc / mozc-utils-gui を導入（apt。IME本体はNix管理外）
#   10. code（--classic）・slack を導入（snap）
#   11. Google Chrome を導入（apt。公式debをダウンロードして導入）
#   12. Grok CLI を導入（公式インストーラー・自動更新版。あえてNix管理外）
#   13. OpenSSH サーバーと Tailscale を導入（iPhoneからの遠隔SSH。本体はNix管理外）
#
# 何度実行しても安全（冪等）。途中で失敗したら原因を解消して再実行すればよい。
# 9〜11・13 はsudoが使えない環境では警告を出してスキップする（bootstrap全体は継続する）。

set -eu

REPO_URL="https://github.com/seino914/ubuntu-dotfiles.git"
BASE_DIR="$HOME/Dev/kaishi"
DOTFILES_DIR="$BASE_DIR/ubuntu-dotfiles"
CURRENT_USER="$(id -un)"

echo "==> 1/13 前提パッケージ（git・curl・zsh）を確認"
if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v zsh >/dev/null 2>&1; then
  echo "不足しているパッケージをaptで導入します"
  sudo apt-get update && sudo apt-get install -y git curl zsh
fi

echo "==> 2/13 Nix を確認"
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

echo "==> 3/13 リポジトリを $DOTFILES_DIR へ配置"
mkdir -p "$BASE_DIR"
if [ ! -d "$DOTFILES_DIR/.git" ]; then
  git clone "$REPO_URL" "$DOTFILES_DIR"
else
  echo "既にクローン済みのためそのまま使います"
fi
cd "$DOTFILES_DIR"

echo "==> 4/13 flake.nix の username をこのマシンのユーザー名 ($CURRENT_USER) に合わせる"
sed -i -E "s|username = \"[^\"]+\";|username = \"$CURRENT_USER\";|" flake.nix
if ! git diff --quiet flake.nix; then
  echo "flake.nix の username を書き換えました。あとでこの差分をコミットしてください"
fi

echo "==> 5/13 home-manager を適用します（sudo不要）"
nix run home-manager/master -- switch --flake ".#ubuntu" -b hm-backup

echo "==> 6/13 ログインシェルを zsh に変更"
if [ "$(basename "$SHELL")" != "zsh" ]; then
  echo "パスワードを求められる場合があります"
  chsh -s "$(command -v zsh)"
else
  echo "既に zsh のためスキップします"
fi

echo "==> 7/13 Oh My Zsh と Powerlevel10k を導入"
if [ -d "$HOME/.oh-my-zsh" ]; then
  echo "Oh My Zsh は既に導入済みのためスキップします"
else
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi
if [ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
  echo "Powerlevel10k は既に導入済みのためスキップします"
else
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
fi

echo "==> 8/13 Claude Code CLI を確認"
if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
  echo "Claude Code をインストールします（公式インストーラー・自動更新あり）"
  curl -fsSL https://claude.ai/install.sh | bash
else
  echo "既にインストール済みのためスキップします"
fi

echo "==> 9/13 ibus-mozc / mozc-utils-gui を確認"
if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo が使用できないためスキップします。ibus-mozc / mozc-utils-gui は手動で導入してください"
else
  if dpkg -s ibus-mozc >/dev/null 2>&1; then
    echo "ibus-mozc は既に導入済みのためスキップします"
  else
    echo "ibus-mozc / mozc-utils-gui をaptで導入します"
    sudo apt-get update && sudo apt-get install -y ibus-mozc mozc-utils-gui
    echo "IMEを有効化するにはログアウト/再ログインしてください"
  fi
fi

echo "==> 10/13 code（--classic）・slack を確認"
if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo が使用できないためスキップします。code / slack は手動で導入してください"
else
  if snap list code >/dev/null 2>&1; then
    echo "code は既に導入済みのためスキップします"
  else
    sudo snap install code --classic
  fi
  if snap list slack >/dev/null 2>&1; then
    echo "slack は既に導入済みのためスキップします"
  else
    sudo snap install slack
  fi
fi

echo "==> 11/13 Google Chrome を確認"
if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo が使用できないためスキップします。Google Chrome は手動で導入してください"
else
  if command -v google-chrome >/dev/null 2>&1; then
    echo "Google Chrome は既に導入済みのためスキップします"
  else
    echo "Google Chrome をダウンロードして導入します"
    CHROME_TMP_DIR="$(mktemp -d)"
    curl -fsSL -o "$CHROME_TMP_DIR/google-chrome-stable_current_amd64.deb" \
      https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt-get install -y "$CHROME_TMP_DIR/google-chrome-stable_current_amd64.deb"
    rm -rf "$CHROME_TMP_DIR"
  fi
fi

echo "==> 12/13 Grok CLI を確認"
if ! command -v grok >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/grok" ]; then
  echo "Grok CLI をインストールします（公式インストーラー・自動更新あり）"
  curl -fsSL https://x.ai/cli/install.sh | bash
else
  echo "既にインストール済みのためスキップします"
fi

echo "==> 13/13 OpenSSH・Tailscale（iPhoneからの遠隔SSH）"
bash "$DOTFILES_DIR/ssh-tailscale/setup.sh"

echo ""
echo "セットアップ完了！"
echo "手動で必要な残作業（~/.claude/claude-notify.json の配置、~/.gitconfig.local の配置、Docker Engineの導入、"
echo "sudo tailscale up、iPhoneのTailscale / SSHアプリ）は nix/README.md と ssh-tailscale/README.md を参照してください。"
echo "tmux は home-manager で入る。iPhone から SSH すると自動で attach し、切断しても grok は残る。"
