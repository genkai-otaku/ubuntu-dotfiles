# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリの性質

Ubuntu用の個人dotfilesリポジトリ。ビルド・lint・テストは存在しない。管理対象は9つ：

- `flake.nix` + `nix/` — **Nix（home-manager standalone）によるUbuntu環境の宣言管理**（CLIツール・GNOMEデスクトップのdconf設定）。`nix/desktop.nix` がテーマ・電源管理・キーバインド・Dock・ウィンドウボタン左上配置等のGNOME設定を、`nix/keyboard.nix` がJIS配列・IME切り替え・キーリピート（delay=250ms。GNOME既定の500msは遅すぎる）と ibus の `embed-preedit-text = false`（VSCode 統合ターミナルの TUI 向け。true に戻さない）を宣言する。`bootstrap.sh` が新Ubuntuマシンの1コマンドセットアップを担う（Nix管理外のapt/snapアプリ導入も含む。後述）
- `vscode/` — **VSCode / Cursor 共通の設定実体**（settings.json・keybindings.json・拡張機能リスト・Linux IME 用起動ラッパー `code`）。`home.nix` が両エディタのUserディレクトリ（`~/.config/{Code,Cursor}/User/`）へ書き込み可能リンクを張り、`install-extensions.sh` が activation 時に拡張機能を導入する。エディタ本体はNix管理外（apt/snap等で手動導入）のため `programs.vscode` モジュールは使わない。ウィンドウボタンの左上一段は GNOME の dconf では効かないので `settings.json` の `window.titleBarStyle` / `menuStyle` / `menuBarVisibility` をセットで持つ（詳細は `vscode/README.md`）。この3つは欠けると右上に戻るか二段メニューになるので、片方だけ変えないこと。統合ターミナルで grok / Claude Code の日本語が崩れる問題の本体対策は `keyboard.nix`（`vscode/README.md` の「統合ターミナルの日本語IME」）
- `.claude/` — Claude Codeの**グローバル設定の実体**（settings.json・CLAUDE.md・hooks・skills）
- `git/` — **gitconfigの実体**（`.gitconfig`）。`home.nix` が `~/.zshrc` と同じ `mkOutOfStoreSymlink` 方式で `~/.gitconfig` へ書き込み可能リンクを張る（既存の実体ファイルを置き換えるため `force = true`）。credential helperはユーザー名非依存のPATH上の `gh` を使う形に正規化してある。**user.name / user.email はリポジトリ（PUBLIC）に含めない**。各PCで `~/.gitconfig.local`（git管理外）に手動配置し、`.gitconfig` 末尾の include で読み込む。gh の `co: pr checkout` エイリアスは `~/.config/gh/config.yml` をgh自身が書き換えるためファイルリンクにはせず、`home.nix` の `home.activation` で `gh alias set` を冪等に実行する
- `grok/` — **Grok CLI（xAI）の設定実体**（`config.toml` と `AGENTS.md`）。`home.nix` が `mkOutOfStoreSymlink` で `~/.grok/config.toml`・`~/.grok/AGENTS.md` へ書き込み可能リンクを張る。`AGENTS.md` には**Grok固有の補足のみ**（CLAUDE.mdのモデル運用ポリシーのGrok向け読み替え：`spawn_subagent` / explore・plan・general-purpose の使い分け等）を書く。言語・Git制限・Nix運用などの共通ルールはGrokがClaude互換モード（デフォルト有効）で `~/.claude/CLAUDE.md` から読み込むため、AGENTS.mdに**重複させないこと**。`config.toml` の `permission_mode = "always-approve"` により、Claude側の `permissions.ask` / `pr-mode.sh`（確認ダイアログ層）はGrokでは効かない。git操作の抑止は指示ファイルに依存する。`auth.json` 等の秘密情報・キャッシュ・セッションは `~/.grok` 直下の実体のまま管理対象外。本体は `claude-code` 同様あえてNix管理外で `bootstrap.sh` が公式インストーラーで導入する
- `zsh/` — zsh設定（`zsh/.zshrc`）。Oh My Zsh + Powerlevel10k テーマを使用し、本体は `bootstrap.sh` が `~/.oh-my-zsh` へ導入（あえてNix管理外）。direnv フックもここへ直書きする。`zsh/.bashrc` は対話bashを即zshへexecする引き継ぎ用（bashは使わない運用。`NO_ZSH=1 bash` で回避可）
- `claude-notify/` — iPhoneへのWeb Push通知の**送信側スクリプト**（`send-push.mjs`）。詳細は後述の「iPhoneプッシュ通知の仕組み」参照
- `.github/workflows/` — **他リポジトリへコピーして使う配布用テンプレート**。ただしリポジトリ内に置かれている以上、`delete-merged-branch.yml`（PRマージ時のブランチ自動削除）は**このリポジトリ自身のPRにも発火する**
- `commands/` — 個人用の早見表メモ（Claude Code組み込みコマンド一覧・よく使う操作の控え）。名前は似ているが `.claude/commands/`（カスタムスラッシュコマンド）ではなく、setup.shのリンク対象でもない単なるドキュメント

## 最重要：`.claude/` の編集は全プロジェクトに即反映される

`~/.claude/CLAUDE.md` や `~/.claude/settings.json` は、このリポジトリの `.claude/` 配下へのシンボリックリンク。したがって：

- `.claude/` 配下を編集すると、コミット前でも**その場で全プロジェクトのClaude Code挙動が変わる**。試験目的の書き換えでも影響範囲を意識すること
- 逆に、セッション内の `/model` や `/config` による設定変更はリンクを辿ってこのリポジトリの `settings.json` に書き込まれ、未コミット差分として現れる
- `.claude/CLAUDE.md` はこのリポジトリ専用の指示ではなく**グローバル指示の実体**。ルートの本ファイルと役割を混同しない

## アーキテクチャ：Nixによる環境管理

`flake.nix` がエントリポイントで、`nix/` 配下の4モジュール（home.nix / packages.nix / keyboard.nix / desktop.nix）を統合する。設計上の不変条件が多いので、編集時は以下を守ること：

- **構成名はホスト名非依存の `ubuntu` 固定**。適用コマンドは常に `--flake <リポジトリ>#ubuntu` と明示する（ホスト名によるフォールバックは意図的に使っていない）
- **`username` はハードコードが正**。flakeは純粋評価で環境変数を読めないため、`bootstrap.sh` がクローン時に `sed` でそのマシンの実ユーザー名へ書き換える設計。`dotfilesPath` は username から導出され、リポジトリ配置は `~/Dev/kaishi/ubuntu-dotfiles` 固定
- **flakeはgit追跡ファイルしか認識しない**。`.nix` ファイルを追加したら `git add` しなければ適用時に「ファイルが存在しない」扱いになる（コミットは不要、ステージングで足りる）
- **`home.nix` の `.claude/` 処理をhome-manager標準管理に「移行」しないこと**。`~/.zshrc` は `mkOutOfStoreSymlink`（書き込み可能リンク）だが、`.claude/` はあえて既存 `setup.sh` をactivationから実行する方式。setup.shのセルフヒーリング（リンクが実体化したとき実体をリポジトリへ取り込む）はhome-managerでは再現できない
- **direnvのzshフックは `zsh/.zshrc` に直書きが正**。direnv本体は `home.nix` の `programs.direnv`（nix-direnv併用）で導入するが、`~/.zshrc` は `mkOutOfStoreSymlink` でhome-manager非管理のため `enableZshIntegration` ではフックを注入できない。VSCode/Cursor側への反映は `vscode/extensions.txt` の `mkhl.direnv` 拡張が担う
- **`claude-code` は意図的にNix管理外**（packages.nixのコメント参照）。常に最新版を使うため公式ネイティブインストーラーの自動更新版を採用し、bootstrap.shが導入する
- **`vscode/` 配下はflake評価時には読まれない**（`mkOutOfStoreSymlink` による絶対パス参照のため）。「git追跡ファイルしか認識しない」ルールの例外で `git add` 不要だが、新しいマシンへ配るにはpushが必要（`bootstrap.sh` はGitHub上のmainをクローンする）。`home.nix` の `editorUserFiles` にある `force = true` は初回適用時に既存実体をリンクへ置き換えるために必要なので外さないこと。拡張機能は `vscode/extensions.txt` から削除しても既存環境からはアンインストールされない（新規環境に入らなくなるだけ）。エディタ本体が未導入ならそのエディタはスキップされ、次回switchで冪等にリトライされる。詳細は `vscode/README.md`
- **ibus の `embed-preedit-text` は `false` が正**（`nix/keyboard.nix`）。true だと VSCode 統合ターミナルの Grok / Claude Code で Mozc の未確定文字が確定扱いされ、「この」が「ｋこｎこのこの」になる。インライン下線より TUI で打てることを優先している。Kitty 無効化・local echo off・`vscode/code` ラッパーは補助で、これだけでは直らない
- **適用（`home-manager switch`）はsudo不要だが環境そのものを書き換えるため、Claude Codeからは実行しない**。設定変更後はユーザーに適用コマンドの実行を依頼する

## コマンド

### Nix環境の適用・更新（ユーザーのターミナルで実行）
```zsh
# 適用（設定ファイル変更後）
home-manager switch --flake ~/Dev/kaishi/ubuntu-dotfiles#ubuntu

# 初回（home-manager未導入時）は bash bootstrap.sh（冪等）か
nix run home-manager/master -- switch --flake .#ubuntu -b hm-backup

# パッケージのバージョン更新（実行後、flake.lock を必ずコミット）
nix flake update
```

### 設定の反映
- `bash .claude/setup.sh` — `.claude/` 配下を `~/.claude` へシンボリックリンク
  - 冪等だが自動実行はされない。**`.claude/` 配下にファイルを追加・削除したら再実行が必要**（スクリプト自体の修正は不要）。なお `home-manager switch` 時にはactivationからも自動実行される
  - リンク対象外：`setup.sh`・`README.md`・`claude-notify.example.json`・`.DS_Store`
  - リンクが実体ファイルで上書きされた場合（claude-code Issue #40857 の既知挙動）は、実体を最新としてリポジトリへ取り込んでからリンクを張り直すセルフヒーリングを持つ
- `source ~/.zshrc` — zsh設定の反映
- VSCode/Cursorの設定・キーバインドは、エディタのUIから変更するだけで即リポジトリの `vscode/` に反映される（書き込み可能リンクのため適用コマンド不要）。`vscode/extensions.txt` に追記した拡張機能の導入のみ `home-manager switch` が必要

### 配布用ワークフローの導入（導入先リポジトリのルートで実行）
```zsh
mkdir -p .github/workflows
cp ~/Dev/kaishi/ubuntu-dotfiles/.github/workflows/*.yml .github/workflows/
```

## アーキテクチャ：/pr フローの三層構造

git commit / git push / PR作成の制御は三層で成り立っており、**一層だけ変更すると整合が壊れる**：

1. `.claude/CLAUDE.md` — `/pr` 指示があるまでgit操作を禁止する指示
2. `.claude/settings.json` の `permissions.ask` — `git commit` / `git push` / `gh pr create` / `gh pr merge` を常に確認対象にする
3. `.claude/hooks/pr-mode.sh` — `/pr` 実行中だけ上記の確認を自動承認するフラグ管理

`pr-mode.sh` には実装上の制約がコメントで明記されている。変更時は以下に注意：

- `/pr` かどうかの判定は `UserPromptExpansion` の `command_name` でのみ可能（`UserPromptSubmit` のpromptには展開後の本文しか入らず判定できない）
- 自動承認は `PermissionRequest` フックで返す（`PreToolUse` の `permissionDecision=allow` では `permissions.ask` を上書きできないため）
- フラグファイルは `${TMPDIR:-/tmp}/claude-pr-mode-<session_id>`。`Stop` で削除し、15秒より古い残骸は `UserPromptSubmit` で掃除する

## iPhoneプッシュ通知の仕組み（claude-notify）

`.claude/hooks/notify.sh` が `Stop` / `Notification` フックから呼ばれ、**このリポジトリ内の** `claude-notify/send-push.mjs` を経由してWeb PushでiPhoneのPWAへ通知する。受信側のPWAのみ別リポジトリ `claude-notify-mobile`（Vercel配信）にある。設計上の注意：

- notify.sh は自身の実体パス（`readlink -f`）から dotfiles ルートを解決して送信スクリプトを見つける。環境変数 `CLAUDE_NOTIFY_REPO` は不要になった（PCごとのパス差はリンク解決で吸収される）
- notify.sh は**何が起きても即 exit 0**（送信スクリプト・jq・nodeの欠如、依存未インストールでも静かに終了し、Claude Codeを止めない）。送信はnohupでバックグラウンド実行
- **Grok CLI からも同じ通知が飛ぶ**。Grok は Claude 互換モード（`compat.claude.hooks`、デフォルト有効）で `~/.claude/settings.json` の hooks を自動実行するため追加登録は不要。ただし Grok の stdin JSON は camelCase（`hookEventName` 等）のため、notify.sh は環境変数 `GROK_HOOK_EVENT` で判別してイベント名を正規化し、通知スパム防止のため **Stop は `reason == "end_turn"` のみ・Notification は `notificationType == "permission_prompt"` のみ**送信する（idle_prompt は Stop と重複するため捨てる）。タイトルには「(Grok)」を付けて区別する
- 送信スクリプトは `web-push` に依存する。`claude-notify/node_modules` は `.gitignore` 対象で、`nix/home.nix` の `home.activation.installClaudeNotifyDeps` が `home-manager switch` 時に `pnpm install --frozen-lockfile` を実行して用意する（失敗してもsoft failでswitchは止めない）
- VAPID鍵・購読情報は `~/.claude/claude-notify.json` に手動配置する（リポジトリには `claude-notify.example.json` のみ含める。**記入済みファイルは秘密鍵を含むため絶対にコミットしない**）
- 実行ログは `~/.claude/claude-notify.log` に追記される
- 新PCでのセットアップ手順・疎通テストは `.claude/README.md`、受信側PWAの設計は claude-notify-mobile リポジトリの `docs/SETUP.md` を参照
