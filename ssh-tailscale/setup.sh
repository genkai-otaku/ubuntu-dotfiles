#!/bin/bash
# OpenSSH サーバーと Tailscale を冪等に導入する。
# bootstrap.sh と home-manager switch（activation）の両方から呼ばれる。
# 単体実行もできるが、通常は README の適用コマンドに任せる。
#
# やること:
#   1. openssh-server を入れて ssh を起動（起動時自動）
#   2. Tailscale を公式インストーラーで入れて tailscaled を起動（起動時自動）
#   3. 未ログインなら `sudo tailscale up` を促す
#
# やらないこと:
#   - `tailscale up` のブラウザログイン（対話が必要なので手動）
#   - PasswordAuthentication の無効化（鍵で入れる確認前にやると復旧が面倒）
#   - `ufw enable`（既存の LAN サービスを落とす可能性がある）
#
# sudo:
#   対話端末（bootstrap）ではパスワードを尋ねる。
#   home-manager switch 中は TTY が無いので、入っていれば確認だけして終わる。

set -eu

service_ready() {
  systemctl is-enabled --quiet "$1" && systemctl is-active --quiet "$1"
}

run_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo が使えないためスキップします: $*"
    return 1
  fi
  if sudo -n true 2>/dev/null; then
    sudo -n "$@"
    return
  fi
  if [ -t 0 ]; then
    sudo "$@"
    return
  fi
  echo "sudo のパスワードが必要なためスキップします（ターミナルで bootstrap.sh を実行してください）: $*"
  return 1
}

ssh_tailscale_ready() {
  dpkg -s openssh-server >/dev/null 2>&1 \
    && service_ready ssh \
    && command -v tailscale >/dev/null 2>&1 \
    && command -v tailscaled >/dev/null 2>&1 \
    && service_ready tailscaled \
    && tailscale ip -4 >/dev/null 2>&1
}

if ssh_tailscale_ready; then
  echo "OpenSSH / Tailscale OK  user=$(id -un)  ip=$(tailscale ip -4)"
  exit 0
fi

echo "==> OpenSSH サーバー"
if dpkg -s openssh-server >/dev/null 2>&1; then
  echo "openssh-server は既に導入済み"
else
  run_sudo apt-get update && run_sudo apt-get install -y openssh-server || true
fi
if dpkg -s openssh-server >/dev/null 2>&1; then
  if service_ready ssh; then
    echo "ssh は既に有効"
  else
    run_sudo systemctl enable --now ssh || true
  fi
fi

echo "==> Tailscale"
if command -v tailscale >/dev/null 2>&1 && command -v tailscaled >/dev/null 2>&1; then
  echo "tailscale は既に導入済み"
else
  if command -v sudo >/dev/null 2>&1 && { sudo -n true 2>/dev/null || [ -t 0 ]; }; then
    curl -fsSL https://tailscale.com/install.sh | sh || echo "警告: Tailscale の導入に失敗しました"
  else
    echo "sudo のパスワードが必要なため Tailscale 導入をスキップします（ターミナルで bootstrap.sh を実行してください）"
  fi
fi
if command -v tailscaled >/dev/null 2>&1; then
  if service_ready tailscaled; then
    echo "tailscaled は既に有効"
  else
    run_sudo systemctl enable --now tailscaled || true
  fi
fi

echo ""
echo "==> 状態"
echo "ユーザー名: $(id -un)"
if command -v tailscale >/dev/null 2>&1; then
  if TS_IP="$(tailscale ip -4 2>/dev/null)"; then
    echo "Tailscale IPv4: $TS_IP"
    echo "MagicDNS: $(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Self',{}).get('DNSName','').rstrip('.'))" 2>/dev/null || true)"
    tailscale status
  else
    echo "Tailscale は未ログインです。ターミナルで次を実行し、表示されたURLでログインしてください:"
    echo "  sudo tailscale up"
  fi
else
  echo "tailscale コマンドがありません"
fi
echo "ssh:        $(systemctl is-active ssh 2>/dev/null || echo unknown) / $(systemctl is-enabled ssh 2>/dev/null || echo unknown)"
echo "tailscaled: $(systemctl is-active tailscaled 2>/dev/null || echo unknown) / $(systemctl is-enabled tailscaled 2>/dev/null || echo unknown)"
echo ""
echo "iPhone からの接続手順は ssh-tailscale/README.md を参照してください。"
