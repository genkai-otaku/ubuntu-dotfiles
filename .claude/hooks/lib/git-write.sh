#!/bin/bash
# Claude Code と Codex で共有する、状態を持たない Git 書き込みの判定。
# 呼び出し側が STRIP_AWK を設定してから source する。

# 引用符の中身と HEREDOC 本文を除去する。失敗時は ";" を返して複合扱いにする
strip_cmd() {
  local out
  if [ ! -f "$STRIP_AWK" ]; then printf ';'; return; fi
  out=$(printf '%s\n' "$1" | awk -f "$STRIP_AWK" 2>/dev/null) || { printf ';'; return; }
  if [ -z "$out" ] && [ -n "$1" ]; then printf ';'; return; fi
  printf '%s' "$out"
}

# 拒否判定用: 除去に失敗したとき（awk が無い等）は生文字列で判定する。
# ";" だけを返して「何も含まない」と見なすと拒否側が fail-open になるため
stripped_or_raw() {
  local st
  st=$(strip_cmd "$1")
  [ "$st" = ';' ] && st="$1"
  printf '%s' "$st"
}

# 生文字列で見る判定（bash -c "git commit" のようにシェルへ文字列で渡す形）用に、
# HEREDOC 本文だけを取り除いた生文字列を返す。引用符とその中身は残す。
# HEREDOC 本文は bash が実行しない「書き込まれるファイルの中身」なので、本文に出てくる
# eval や git commit の語を実コマンドと誤認しないために除く（スクリプトを heredoc で
# 書き出すだけのコマンドが拒否される誤検知を防ぐ）。
# keepq 版は引用符の中の空白を \001 に置き換えるので、語として見られるよう空白へ戻す。
# 取り除きに失敗したら生文字列を返す（fail-open にしない）
raw_no_heredoc() {
  local out
  [ -f "$STRIP_AWK" ] || { printf '%s' "$1"; return; }
  out=$(printf '%s\n' "$1" | awk -v keepq=1 -f "$STRIP_AWK" 2>/dev/null | tr '\001' ' ') || { printf '%s' "$1"; return; }
  if [ -z "$out" ] && [ -n "$1" ]; then printf '%s' "$1"; return; fi
  printf '%s' "$out"
}

# gh api の通常の引数を引用を保持した解析結果から取り出す。
# コマンド位置・エンドポイント・メソッドを分け、資料中の文字列を操作と誤認しない。
is_pr_api_write() {
  local q raw="$1" token command_pos=1 stage=0 endpoint=0 method="" field=0 next_method=0
  raw=${raw//\\$'\n'/ }
  q=$(printf '%s\n' "$raw" | awk -v keepq=1 -v join_quoted_lines=1 -f "$STRIP_AWK" 2>/dev/null) || q="$raw"
  q=${q//$'\n'/;}
  q=$(printf '%s\n' "$q" | sed -E 's/([;&|()])/ \1 /g')
  for token in $q ';'; do
    case "$token" in
      ';' | '&' | '|' | '(' | ')')
        if [ "$endpoint" -eq 1 ]; then
          case "$method" in POST | PUT | PATCH) return 0 ;; '') [ "$field" -eq 1 ] && return 0 ;; esac
        fi
        command_pos=1 stage=0 endpoint=0 method="" field=0 next_method=0
        continue ;;
    esac
    token=${token//\"/}; token=${token//\'/}; token=${token//$'\001'/ }
    if [ "$command_pos" -eq 1 ]; then
      case "$token" in command | env | exec | nohup | time | builtin | [A-Za-z_]*=*) continue ;; esac
      command_pos=0
      case "$token" in gh | */gh | '\gh') stage=1 ;; esac
      continue
    fi
    if [ "$stage" -eq 1 ]; then
      [ "$token" = api ] && stage=2 || stage=0
      continue
    fi
    [ "$stage" -eq 2 ] || continue
    if [ "$next_method" -eq 1 ]; then method="$token"; next_method=0; continue; fi
    case "$token" in
      -X | --method) next_method=1 ;;
      --method=*) method="${token#--method=}" ;;
      -f | -F | --field | --raw-field | --input | --field=* | --raw-field=* | --input=*) field=1 ;;
      *) [[ "$token" =~ ^[^[:space:]]+/pulls(/[0-9]+)?$ ]] && endpoint=1 ;;
    esac
  done
  return 1
}

# 除去後の文字列にコミット・push・PR作成が含まれるか（引数: 生コマンド, 除去後）
is_git_write() {
  local raw="$1" s="$2" rawh
  rawh=$(raw_no_heredoc "$raw")
  # 行継続（\ + 改行）を結合し、改行は区切り ";" にして 1 行で判定する
  s=${s//\\$'\n'/ }
  s=${s//$'\n'/;}
  local wrap='(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|command|env|exec|nohup|time|builtin)[[:space:]]+)*'
  local gitopt='((-[cC]|--git-dir|--work-tree|--namespace)[[:space:]]+[^[:space:]]+[[:space:]]+|--?[A-Za-z][^[:space:]]*[[:space:]]+)*'
  # 末尾は空白・行末のほか ; & | ) も区切りとして扱う（"git push;" / "(git push)" / "{ git push; }" の形）。
  # コマンド語直前の \（\git のエイリアス回避）も許す
  local re="(^|[[:space:];&|(\`])${wrap}([^[:space:]]*/)?\\\\?git[[:space:]]+${gitopt}(commit|push)([[:space:];&|)<>]|\$)"
  # PR の作成（create / 別名 new）と更新（edit）を同じ扱いにする
  local re_gh="(^|[[:space:];&|(\`])${wrap}([^[:space:]]*/)?\\\\?gh[[:space:]]+pr[[:space:]]+(create|new|edit)([[:space:];&|)<>]|\$)"
  printf '%s\n' "$s" | grep -Eq -- "$re" && return 0
  printf '%s\n' "$s" | grep -Eq -- "$re_gh" && return 0
  is_pr_api_write "$raw" && return 0
  # GraphQL の createPullRequest mutation（クエリは引用符の中なので生文字列で見る。
  # gh api / graphql の文脈にあるときだけ。grep createPullRequest のような読み取りでは発動しない）
  case "$s" in *gh*api* | *graphql*) case "$rawh" in *createPullRequest*) return 0 ;; esac ;; esac
  # 引用符・HEREDOC・パイプでシェルに文字列を渡す形（bash -c "…" / sh -c / eval … / bash <<EOF / … | sh）は
  # リテラル判定ができないので生文字列で見る。単語としての eval / sh だけを対象にし、
  # "eval" を含むファイル名等（tests/eval, evaluate）や ssh では発動しない
  if printf '%s\n' "$rawh" | grep -Eq -- '(^|[[:space:];&|(`])(eval[[:space:]]|([^[:space:]]*/)?(ba|z|da|k)?sh[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-[A-Za-z]*c[A-Za-z]*([[:space:]]|$)|([^[:space:]]*/)?(ba|z|da|k)?sh([[:space:]]+-[A-Za-z]+)*[[:space:]]*<<)|\|[[:space:]]*([^[:space:]]*/)?(ba|z|da|k)?sh([[:space:]]|$)'; then
    # HEREDOC やパイプでシェルに流す形（bash <<EOF / … | sh）は、本文そのものが実行されるので生文字列で見る。
    # それ以外（bash -c "…" / eval "…"）は引用符の中に実コマンドがあり、HEREDOC 本文は実行されないので
    # 本文を除いた版で見る（スクリプトを heredoc で書き出すだけのコマンドの誤検知を防ぐ）
    local hay="$rawh"
    if printf '%s\n' "$rawh" | grep -Eq -- '(^|[[:space:];&|(`])([^[:space:]]*/)?(ba|z|da|k)?sh([[:space:]]+-[A-Za-z]+)*[[:space:]]*<<|\|[[:space:]]*([^[:space:]]*/)?(ba|z|da|k)?sh([[:space:]]|$)'; then
      hay="$raw"
    fi
    case "$hay" in *'git commit'* | *'git push'* | *'gh pr create'* | *'gh pr new'* | *'gh pr edit'*) return 0 ;; esac
  fi
  return 1
}

# force push は /pr 中でも deny（Claude の ask も Grok の always-approve も通さない）
is_force_push() {
  local raw="$1" s
  s=$(stripped_or_raw "$raw")
  s=${s//\\$'\n'/ }
  s=${s//$'\n'/;}
  printf '%s\n' "$s" | grep -Eq -- '(^|[[:space:];&|(`])([^[:space:]]*/)?\\?git[[:space:]]+' || return 1
  case "$s" in *"git push"* | *" push "*) ;; *)
    printf '%s\n' "$s" | grep -Eq -- '(^|[[:space:];&|(`])([^[:space:]]*/)?\\?git[[:space:]]+((-[cC]|--git-dir|--work-tree|--namespace)[[:space:]]+[^[:space:]]+[[:space:]]+|--?[A-Za-z][^[:space:]]*[[:space:]]+)*push([[:space:];&|)<>]|$)' || return 1
    ;;
  esac
  case "$s" in *--force* | *--force-with-lease*) return 0 ;; esac
  local saw_push=0 t
  s=$(printf '%s' "$s" | tr ';|&()' ' ')
  for t in $s; do
    [ "$t" = "push" ] && saw_push=1
    if [ "$saw_push" -eq 1 ]; then
      case "$t" in
        -f|--force|--force-with-lease|--force=*|--force-with-lease=*) return 0 ;;
        --*) ;;
        -*) printf '%s' "$t" | grep -Eq -- '^-[A-Za-z]*f[A-Za-z]*$' && return 0 ;;
      esac
    fi
  done
  return 1
}
