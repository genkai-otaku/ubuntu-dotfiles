# ubuntu-dotfiles 固有の指示

Ubuntu用の個人dotfiles。全体像は `README.md`、Nix運用は `nix/README.md`、Claude Code/Grok/OpenCodeの設定は各READMEを参照する。ここには、作業ミスを防ぐリポジトリ固有の制約と検証方法だけを記す。

## 指示ファイル

- このリポジトリの共通指示はこの `AGENTS.md` に集約する。`CLAUDE.md` は作らない。
- OpenCode V2は `AGENTS.md` を読む。Claude Codeもv2.1.277以降、プロジェクト指示の設定が既定の `claude-md-or-agents-md` で、作業ディレクトリより上に `CLAUDE.md` / `CLAUDE.local.md` がない場合は `AGENTS.md` を読む。
- グローバル指示は `.claude/global-instructions.md`（Claude Code / Grok）と `opencode/AGENTS.md`（OpenCode）で管理する。プロジェクト固有ルールをそちらへ重複記載しない。

## リポジトリ固有の制約

- `bootstrap.sh` と `opencode/setup.sh` はソフトウェアをインストールするため、検証目的で実行しない。`home-manager switch` も実行せず、評価後にユーザーへ依頼する。
- Claude Code / Grok / OpenCodeのCLIをNix管理へ移さない。OpenCode認証情報や `~/.claude/claude-notify.json` は読まず、リポジトリにも保存しない。Claude/GrokのHooks・モデル設定がOpenCodeでも動くとは扱わない。
- `nix/home.nix` の構成名は `ubuntu` 固定。`username` を動的取得にしない（flakeは環境変数を読めない）。
- `keyboard.nix` の ibus `embed-preedit-text = false` は戻さない。
- `editorUserFiles` の `force = true` を外さない。`window.titleBarStyle` / `menuStyle` / `menuBarVisibility` は必ず一緒に変更する。
- `direnv` の設定を `enableZshIntegration` に置き換えない。`~/.zshrc` は `mkOutOfStoreSymlink` で管理する。
- `.claude/` は全プロジェクトに反映される。home-manager標準管理へ移さない（`setup.sh` のセルフヒーリングを維持する）。`.claude/rules/` はClaude Code専用なので共通ルールを置かず、`grok/AGENTS.md` に共通ルールを重複させない。
- `/pr` はSkill・共通指示・permission・Hookの四層で整合させる。`skills/pr/SKILL.md` の先頭H1とGrok用 `<!-- pr-mode-enable -->` は `pr-mode.sh` の判定に使うため維持する。OpenCodeではClaude/Grokの `pr-mode.sh` を実行しない。OpenCodeでは `/pr` Command本文を受け取ったこと自体、またはユーザー発言の先頭トークンが `@pr` であることを明示起動として扱う。`@pr` はMarkdownのコード表記・引用符で囲まれていても同じトークンとして認識し、UI上にCommand名が表示されることを追加条件にしない。専用Agentで通常コミット・`origin` へのPR用ブランチprefixのpush・PR作成を許可する。他のセッションでは確認を維持する。force push等は禁止する。
- `.claude/hooks/guard-destructive.sh` の拒否パターンを際限なく増やさない。解釈不能な書き方は説明付き確認に倒す設計を維持する。削除可能ルートは `.claude/dev-roots` だけで定義する。
- `user.name` / `user.email` をリポジトリに書かない。`docs/` はgitignore対象の手元資料置き場。

## ファイル追加・変更

- flakeはgit管理ファイルだけを評価対象にする。新しい `.nix` ファイルを評価する場合は、先にユーザーへ `git add` を依頼する。`vscode/` は評価対象に含められるが、配布にはpushが必要。
- `.claude/` の追加・削除は `bash .claude/setup.sh` で配布する設計。setup対象はgit管理ファイルのみで、`.claude/tests/` はリンク対象外。
- `opencode/` の設定・Command・Agent・Skillは `nix/home.nix` から個別に `~/.config/opencode/` へリンクする。新しいファイルには対応するリンクを追加する。
- `.claude/dev-roots` は1行1パス、`~/` 始まり。`#` 以降・前後の空白・末尾 `/` は無視する。読む側は `guard-destructive.sh`・`nix/home.nix`（`devDirs`）・`tests/test-guard-destructive.sh`。変更時はユーザーに `git add .claude/dev-roots` を依頼し、Nix評価・テスト・配布手順を確認する。

## 検証

- プロジェクトに明記された検証コマンドだけを実行する。失敗したら自分の変更に関係する場合のみ修正し、テストの無効化・削除や期待値の変更で通さない。
- `flake.nix` または `nix/` の変更後：`nix eval --raw .#homeConfigurations.ubuntu.activationPackage.drvPath`。
- `.claude/` または `bootstrap.sh` の変更後：`bash .claude/tests/run.sh`。
- OpenCode設定JSONの変更後：`jq empty opencode/opencode.json opencode/cli.json`。
- シェル変更時：対象に応じて `bash -n bootstrap.sh`、`bash -n opencode/setup.sh`、`bash -n zsh/.zshrc`。
- 検証コマンドが該当箇所に明記されていない場合は、探し回らず最終報告に「未検証」と記す。
