# 共通ルール

- 返答・説明・コメント・レビュー結果・確認時の操作案内は日本語にする。成果物の言語はプロジェクトの既存ドキュメントに合わせる。CLIコマンド、設定キー、ファイルパス、モデルIDなどの技術識別子は原文のままにする。
- 作業を終えても変更は未コミットのまま残して内容を報告する。`git commit`・`git push`・PR作成は、ユーザーが `/pr` を明示したときだけ行う。自然言語の依頼だけでは実行せず、`/pr` を案内する。
- force push、デフォルトブランチへの push、`gh pr merge` は禁止。履歴・作業ツリーを壊す git 操作や重要ファイルの削除は、OpenCodeの確認なしに実行しない。
- `.env`・秘密鍵・トークン・認証情報は読まない・出力しない・コミットしない。必要ならテンプレートを使う。
- 検証コマンドはプロジェクトの `AGENTS.md` 等に明記されていれば実行する。なければ探し回らず、報告に「未検証」と記す。テストを無効化・削除したり、期待値を変えて通したりしない。
- グローバル環境は `~/Dev/kaishi/ubuntu-dotfiles` の home-manager が管理する。`apt`・`snap`・`npm install -g`・`pip install --user`・`nix profile install` 等の恒久的なインストール、`sudo`、`home-manager switch` はユーザーの明示指示なしに実行しない。
- 開発ツールは各プロジェクトのNix devShellに宣言する。必要なコマンドは `nix develop -c <cmd>` または `direnv exec . <cmd>` で実行する。
- Claude Code固有の Hooks・モデル振り分け・settings.json はOpenCodeでは動かない。OpenCodeの権限設定と `/pr` Skill の手順に従い、許可ダイアログを迂回しない。

# `/pr` の制約

- `/pr` Command本文が展開されたセッションでは、その本文の受信を明示起動の証拠として扱い、再確認せずSkillを実行する。通常の会話で `/pr` に言及しただけの場合は実行しない。
- OpenCodeはClaude/Grokの `pr-mode.sh` を実行しない。明示的な `/pr` 起動は `pr` Skillに記載された通常コミット・`origin` へのPR用ブランチprefixのpush・PR作成を承認する。専用Agent以外では確認を維持し、force push・デフォルトブランチへのpush・PRマージは許可しない。
- 破壊的なgit操作、force push、`gh pr merge` は `/pr` 中でも実行しない。
