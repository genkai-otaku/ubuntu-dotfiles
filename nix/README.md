# Nixによる Ubuntu 環境管理

Nix（home-manager standalone）でUbuntu環境を宣言的に管理するための設定ディレクトリ。
新しいUbuntuマシンでもリポジトリをクローンして適用コマンドを実行するだけで、CLIツール・dotfilesが再現される。

## ファイル構成

| ファイル | 役割 |
|---|---|
| [`../bootstrap.sh`](../bootstrap.sh) | 新しいUbuntuマシンの1コマンドセットアップ。`~/Dev/kaishi` の作成・クローン・ユーザー名の自動書き換え・初回適用までを行う |
| [`../flake.nix`](../flake.nix) | エントリポイント。home-manager standaloneの `homeConfigurations."ubuntu"` を定義し、ホスト名に依存しない構成名 `ubuntu` を固定する。ユーザー名（`username`）はbootstrap.shがそのマシンに合わせて自動で書き換える |
| [`packages.nix`](packages.nix) | CLIツール群（git・gh・Node.js・pnpm・Docker CLI・docker-compose・supabase-cli・jq等）。バージョンは `flake.lock` で固定される |
| [`home.nix`](home.nix) | home-manager設定。`~/.zshrc` と VSCode/Cursor 設定（`../vscode/` の settings.json・keybindings.json）の書き込み可能リンク、拡張機能の自動インストール（`../vscode/install-extensions.sh`）、`.claude/` 配下のリンク処理（既存 `setup.sh` をactivation時に自動実行） |
| [`keyboard.nix`](keyboard.nix) | GNOMEのキーボード設定（`dconf.settings`）。JIS配列・半角/全角キーでのIME切り替えという「Windowsの初期状態と同じ」挙動をdconfで宣言し、GUIから行われたキー入れ替え等の変更を次回switch時に打ち消す。ibus-mozc本体はNix管理外（`apt install ibus-mozc` で導入する） |

## 新しいUbuntuマシンのセットアップ手順

ユーザー名・`~/Dev/kaishi` の有無にかかわらず、これ1コマンドで完了する：

```zsh
curl -fsSL https://raw.githubusercontent.com/seino914/ubuntu-dotfiles/main/bootstrap.sh | bash
```

[bootstrap.sh](../bootstrap.sh) が以下を自動で行う（冪等なので何度実行してもよい）：

1. 前提パッケージの確認（git・curl・zshをaptで導入）
2. Nixのインストール（Determinate Systemsインストーラー。flakesが最初から有効）
3. `~/Dev/kaishi` を作成してリポジトリをクローン
4. `flake.nix` の `username` をそのマシンの実際のユーザー名に書き換え
5. home-managerの初回適用
6. ログインシェルをzshへ変更（`chsh`）＋ Claude Code CLIの導入（常に最新版を使うため、Nix管理ではなく公式インストーラーの自動更新版を採用）

ユーザー名が書き換わった場合は、適用後に `flake.nix` の差分をコミットしておく。

```zsh
# 2回目以降の適用
home-manager switch --flake ~/Dev/kaishi/ubuntu-dotfiles#ubuntu
```

初回適用時、既存の `~/.zshrc` は `~/.zshrc.hm-backup` へ退避され、リポジトリ実体への新しいリンクに置き換わる。

### 手動で必要な操作（自動化できないもの）

- **Docker Engineのapt導入** — Docker DesktopではなくDocker Engineを公式aptリポジトリから導入し、導入後は現在のユーザーを `docker` グループへ追加する（`sudo usermod -aG docker $USER`。反映には再ログインが必要）。Nix側の `docker`（CLI）はこのDockerデーモンに接続するクライアントとして使う
- **GUIアプリの手動導入** — Chrome・VSCode・Slack等は宣言管理の対象外。aptリポジトリ・snap・公式debパッケージで個別に導入する（VSCode/Cursorは本体のみ手動導入で、設定・拡張機能は`vscode/`配下で宣言管理される）
- **`~/.claude/.line-env` の手動配置** — `.claude/.line-env.example` を参考に。実トークンはコミット禁止
- **各アプリへのサインイン** — Chrome同期・Docker Hub・Slack等

## よくある操作

### CLIツールを追加・削除する

`packages.nix` の `home.packages` を編集して適用。
パッケージ名は https://search.nixos.org/packages で検索できる。

### GUIアプリを追加・削除する

宣言管理の対象外。apt（`apt install`）またはsnap（`snap install`）で手動導入・削除する。

### GNOME設定を宣言化したい場合

home-manager の `dconf.settings` を使えば、GNOMEのデスクトップ設定も宣言管理に含められる。キーボード設定（JIS配列・IME切り替え）は [`keyboard.nix`](keyboard.nix) で導入済み。キーリピート等、他のGNOME設定を追加したい場合も同様に `dconf.settings` へ書き足す。

### パッケージを更新する

```zsh
cd ~/Dev/kaishi/ubuntu-dotfiles
nix flake update
home-manager switch --flake .#ubuntu
```

更新後は `flake.lock` を必ずコミットすること。`flake.lock` が全パッケージのバージョンを固定しており、新しいマシンでの再現性の要になっている。

## 注意

- flakeは**gitに追跡されているファイルしか認識しない**。新しい `.nix` ファイルを追加したら `git add` してから適用すること
- リポジトリの配置は `~/Dev/kaishi/ubuntu-dotfiles` 固定（`flake.nix` の `dotfilesPath` がユーザー名から自動で導かれる）。別の場所に置きたい場合は `dotfilesPath` と `bootstrap.sh` の両方を変更する
- 構成名はホスト名に依存しない固定名 `ubuntu`。適用コマンドでは常に `#ubuntu` を明示する
- `system` は `x86_64-linux` を既定にしている。ARM環境（aarch64）で使う場合は `flake.nix` の `system` を `aarch64-linux` に手動で変更すること
