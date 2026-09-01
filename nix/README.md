# Nixによる Ubuntu 環境管理

Nix（home-manager standalone）でUbuntu環境を宣言的に管理するための設定ディレクトリ。
新しいUbuntuマシンでもリポジトリをクローンして適用コマンドを実行するだけで、CLIツール・dotfilesが再現される。

## ファイル構成

| ファイル | 役割 |
|---|---|
| [`../bootstrap.sh`](../bootstrap.sh) | 新しいUbuntuマシンの1コマンドセットアップ。クローン・username書き換え・home-manager適用に加え、Oh My Zsh・Claude Code / Grok CLI・IME・VSCode / Slack / Chrome まで冪等に導入する |
| [`../flake.nix`](../flake.nix) | エントリポイント。home-manager standaloneの `homeConfigurations."ubuntu"` を定義し、ホスト名に依存しない構成名 `ubuntu` を固定する。ユーザー名（`username`）はbootstrap.shがそのマシンに合わせて自動で書き換える |
| [`packages.nix`](packages.nix) | CLIツール群（git・gh・vim・Node.js・pnpm・Docker CLI・docker-compose・supabase-cli・jq）と Nerd Font（UbuntuMono）。バージョンは `flake.lock` で固定される |
| [`home.nix`](home.nix) | home-manager設定。`~/.zshrc` / `~/.bashrc` / `~/.p10k.zsh` / `~/.gitconfig` / Grok 設定 / VSCode/Cursor 設定の書き込み可能リンク、VSCode IME 用起動ラッパー（`~/.local/bin/code`）と snap desktop の上書き、拡張機能の自動インストール、direnv + nix-direnv、`.claude/` の setup.sh、claude-notify の `pnpm install`、gh の `co` エイリアス、GNOME Terminal のフォント・配色・透明度・サイズ、既定ブラウザ（Chrome） |
| [`keyboard.nix`](keyboard.nix) | GNOMEのキーボード設定（`dconf.settings`）・Mozcのibusエンジン設定（`~/.config/mozc/ibus_config.textproto`）・カスタムxkbオプション（`~/.config/xkb`。CapsLock単押しを大文字ロックなしの半角/全角キー相当にしてIME切り替え専用にする）。JIS配列・半角/全角キーおよびCapsLockでのIME切り替えという「Windowsの初期状態と同じ」挙動を宣言し、GUIから行われたキー入れ替え等の変更を次回switch時に打ち消す。キーリピートは `org/gnome/desktop/peripherals/keyboard` で delay=250ms（Windows Short / Mac GUI 最短付近。GNOME既定の500msだと押しっぱなしが遅く感じる）、repeat-interval=30ms（GNOME既定のまま、Windows 既定とほぼ同じ）。Mozcのエンジンレイアウトは`"jp"`に固定（既定の`"default"`だとmozc使用中にシステム既定のusレイアウトが残り、IME切り替えキーが送出されない）。ibus の `embed-preedit-text` は `false`（変換中プレビューをアプリへ埋め込まずフローティング窓に出す。VSCode 統合ターミナルの TUI で未確定文字が確定扱いされるのを防ぐ）。ibus-mozc本体はNix管理外（`apt install ibus-mozc` で導入する） |
| [`desktop.nix`](desktop.nix) | GNOMEデスクトップ設定（`dconf.settings`）。ダークテーマ（Yaruパープル）、ウィンドウボタンの左上配置、画面ロック/自動スリープ無効、マウス速度、Dock常駐アプリ、dash-to-dock / tiling-assistant、GNOME Terminal の Ctrl+C/V、ロック画面への通知オフなど。キーボード配列は `keyboard.nix`、端末のフォント・配色は `home.nix`。VSCode / Cursor は独自タイトルバーのためこの `button-layout` を無視するので、左上配置は [`../vscode/README.md`](../vscode/README.md) 側 |

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
6. ログインシェルをzshへ変更（`chsh`）
7. Oh My Zsh と Powerlevel10k を導入（あえてNix管理外。`~/.oh-my-zsh` へ git clone）
8. Claude Code CLIの導入（常に最新版を使うため、Nix管理ではなく公式インストーラーの自動更新版を採用）
9. ibus-mozc / mozc-utils-gui をaptで導入
10. VSCode（`code --classic`）と Slack をsnapで導入
11. Google Chrome を公式debで導入
12. Grok CLIの導入（公式インストーラーの自動更新版。あえてNix管理外）

ステップ5の初回 `home-manager switch` はステップ10の VSCode 導入より先に走るため、その時点では拡張機能のインストールはスキップされる。bootstrap完了後にもう一度 `home-manager switch` すれば入る。9〜11 はsudoが使えない環境では警告してスキップする。

ユーザー名が書き換わった場合は、適用後に `flake.nix` の差分をコミットしておく。

```zsh
# 2回目以降の適用
home-manager switch --flake ~/Dev/kaishi/ubuntu-dotfiles#ubuntu
```

初回適用時、既存の `~/.zshrc` は `~/.zshrc.hm-backup` へ退避され、リポジトリ実体への新しいリンクに置き換わる。

### 手動で必要な操作（自動化できないもの）

- **Docker Engine** — 公式aptから導入し、ユーザーを `docker` グループへ追加する（`sudo usermod -aG docker $USER`。再ログインが必要）。Nix の `docker` はデーモンへ接続する CLI
- **Cursor** — 使う場合のみ手動導入（Chrome / VSCode / Slack / ibus-mozc は bootstrap が導入する。設定と拡張機能は `vscode/`）
- **`~/.gitconfig.local`** — `user.name` / `user.email`（PUBLIC に含めない。`git/.gitconfig` 末尾の include で読む）
- **`~/.claude/claude-notify.json`** — iPhone 通知を使う場合。example をコピー。VAPID 秘密鍵のためコミット禁止。詳細は [`../.claude/README.md`](../.claude/README.md)
- **サインイン** — Chrome、Slack、`gh auth login`、SSH 鍵

日本語 Ubuntu（`ja_JP.UTF-8`、`Asia/Tokyo`）を想定する。英語版から入れた場合はタイムゾーンとロケールを合わせる。

## よくある操作

### CLIツールを追加・削除する

`packages.nix` の `home.packages` を編集して適用。
パッケージ名は https://search.nixos.org/packages で検索できる。

### GUIアプリを追加・削除する

宣言管理の対象外。apt（`apt install`）またはsnap（`snap install`）で手動導入・削除する。

### GNOME設定を変更する

- 見た目・電源・Dock・端末キーバインド等 → [`desktop.nix`](desktop.nix)
- ウィンドウボタンの左上配置 → [`desktop.nix`](desktop.nix) の `button-layout`。VSCode / Cursor は独自タイトルバーなので [`../vscode/settings.json`](../vscode/settings.json)（`native` + `compact`）。詳細は [`../vscode/README.md`](../vscode/README.md)
- キーボード配列・IME切り替え・キーリピート（delay / repeat-interval） → [`keyboard.nix`](keyboard.nix)
- GNOME Terminal のフォント・配色・透明度・サイズ → [`home.nix`](home.nix) のプロファイル設定（UUIDはUbuntu既定のもの）

いずれも `dconf.settings`。追加・変更したら `home-manager switch`。GUIから変えた内容は次回switchで宣言値に戻る。

### 統合ターミナルの日本語IME（Grok / Claude Code）

VSCode の統合ターミナルで grok / claude に「この」と打つと「ｋこｎこのこの」になる問題。本体の対策は [`keyboard.nix`](keyboard.nix) の `embed-preedit-text = false`（変換中プレビューをアプリへ埋め込まない）。Kitty・local echo・VSCode 起動ラッパーは補助で、これだけでは直らなかった。詳細・戻してはいけない理由は [`../vscode/README.md`](../vscode/README.md) の「統合ターミナルの日本語IME」を見る。

### パッケージを更新する

```zsh
cd ~/Dev/kaishi/ubuntu-dotfiles
nix flake update
home-manager switch --flake .#ubuntu
```

更新後は `flake.lock` を必ずコミットすること。`flake.lock` が全パッケージのバージョンを固定しており、新しいマシンでの再現性の要になっている。

## 注意

- direnvは`home.nix`の`programs.direnv`（nix-direnv併用）で導入している。`.envrc`のあるプロジェクトディレクトリに`cd`すると、そのプロジェクトの`flake.nix`のdevShellが自動で有効化/無効化される。ただし`~/.zshrc`は`mkOutOfStoreSymlink`管理（home-manager非管理）のため`enableZshIntegration`ではzshフックが注入されず、フックは[`../zsh/.zshrc`](../zsh/.zshrc)に直接記述している
- flakeは**gitに追跡されているファイルしか認識しない**。新しい `.nix` ファイルを追加したら `git add` してから適用すること
- リポジトリの配置は `~/Dev/kaishi/ubuntu-dotfiles` 固定（`flake.nix` の `dotfilesPath` がユーザー名から自動で導かれる）。別の場所に置きたい場合は `dotfilesPath` と `bootstrap.sh` の両方を変更する
- 構成名はホスト名に依存しない固定名 `ubuntu`。適用コマンドでは常に `#ubuntu` を明示する
- `system` は `x86_64-linux` を既定にしている。ARM環境（aarch64）で使う場合は `flake.nix` の `system` を `aarch64-linux` に手動で変更すること
