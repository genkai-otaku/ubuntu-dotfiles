# Powerlevel10k instant prompt（zshrc内で最も早い段階に置くこと）
# ここより前にコンソール出力するコードを置かないこと（キャッシュ・チェックサム系コマンド以外）
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh 本体（bootstrap.shが ~/.oh-my-zsh へ導入する。あえてNix管理外）
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)

# 未導入環境でも壊れないようにガードする
[[ -d $ZSH ]] && source "$ZSH/oh-my-zsh.sh"

# Oh My Zshが LESS=-R を設定してしまい、`git branch` 等の短い出力でも
# 全画面のページャーが開いて終了時に消える挙動になるため上書きする。
# -F: 1画面に収まる出力はページャーを開かずそのまま表示
# -R: 色エスケープをそのまま通す
# -X: ページャー終了時に画面を復元しない（出力が残る）
export LESS='-FRX'

# Powerlevel10kの設定（zsh/.p10k.zsh をリポジトリで管理。macOS風の最小構成）
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# direnv: .envrc のあるディレクトリで devShell を自動ON/OFF（nix/home.nix で導入）
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
