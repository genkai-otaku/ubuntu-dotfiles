# Powerlevel10k の設定。`p10k configure` の生成物ではなく手書きの最小構成。
# macOS標準ターミナルのプロンプト「user@host dir %」に寄せた、
# 左側のみ・1行・背景色なしのコンパクトな見た目にする。
# 変更後は `source ~/.zshrc` か新しいターミナルで反映される。

# 表示セグメントは左側のみ。右プロンプトは使わない（横に広がるのを防ぐ）
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs prompt_char)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

# 1行・フラット表示（背景色や区切り装飾を全て無効化）
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
typeset -g POWERLEVEL9K_BACKGROUND=
typeset -g POWERLEVEL9K_{LEFT,RIGHT}_{LEFT,RIGHT}_WHITESPACE=
typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SUBSEGMENT_SEPARATOR=' '
typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SEGMENT_SEPARATOR=
typeset -g POWERLEVEL9K_VISUAL_IDENTIFIER_EXPANSION=

# user@host（macOSと同様に常時表示・無色）
typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%n@%m'
typeset -g POWERLEVEL9K_CONTEXT_FOREGROUND=default

# カレントディレクトリは最後の1階層のみ（macOSの %1~ 相当。ホームは ~）。
# 色は黒背景でも読める明るい青（256色の39。ANSI標準の暗い青は黒背景と同化する）
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
typeset -g POWERLEVEL9K_DIR_FOREGROUND=39

# gitセグメントは「ブランチアイコン＋ブランチ名」だけ表示する
# （既定で付く変更あり「●」・未追跡「?」などのマーカーは非表示。状態は下記の色で分かる）。
# detached HEAD時はコミットハッシュ先頭8桁を表示する
typeset -g POWERLEVEL9K_VCS_CONTENT_EXPANSION=' ${${VCS_STATUS_LOCAL_BRANCH:-${VCS_STATUS_COMMIT[1,8]}}//\%/%%}'

# gitブランチ表示の色。既定色は「色付き背景＋暗い文字」前提で、
# 背景なしの本構成では黒背景と同化するため、明るい色を明示する
# （クリーン: 緑 / 変更あり: 黄 / コンフリクト: 赤）
typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=76
typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178
typeset -g POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND=196
typeset -g POWERLEVEL9K_VCS_LOADING_FOREGROUND=244

# プロンプト記号はmacOSと同じ「%」（直前コマンド成功で緑・失敗で赤）
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_CONTENT_EXPANSION='%%'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_CONTENT_EXPANSION='%%'
