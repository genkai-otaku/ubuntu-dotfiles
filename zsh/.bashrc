# bashは使わない運用のため、対話的に起動されたら即zshへ引き継ぐ。
# ログインシェルがbashのままの環境（chsh未実行）でも常にzshになる保険。
# どうしてもbashが必要なときは NO_ZSH=1 bash で起動する。

# 非対話（スクリプト実行など）では何もしない
case $- in
*i*) ;;
*) return ;;
esac

if [ -t 1 ] && [ -z "${ZSH_VERSION:-}" ] && [ -z "${NO_ZSH:-}" ] && command -v zsh >/dev/null 2>&1; then
  exec zsh
fi
