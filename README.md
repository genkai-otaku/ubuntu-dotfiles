# dotfiles

## 概要
Ubuntu環境全体をNix（home-manager standalone）で宣言的に管理する個人用dotfilesリポジトリ。CLIツールやGNOMEデスクトップ設定（テーマ・電源管理・キーバインド・Dock等）に加え、ターミナル（zsh / Oh My Zsh / Powerlevel10k）、tmux（iPhone SSH切断後も grok を残す）、VSCode / Cursor の共通設定（settings・keybindings・拡張機能）、gitconfig、Claude Codeのグローバル設定（フック・スキル・permissionsなど）、Grok CLI（xAI）の設定もあわせて管理する。`.claude/`配下は`.claude/setup.sh`で`~/.claude`へシンボリックリンクされ（`home-manager switch`時にactivationからも自動実行される）、このリポジトリを編集するだけで全プロジェクトのClaude Code設定に反映される。共通のGitHub Actionsワークフロー（`.github/`）もここで管理し、他リポジトリへコピーして使う。Nixで管理できないGUIアプリ・IME（Google Chrome・VSCode・Slack・ibus-mozc等）やOh My Zsh・Claude Code・Grok CLI、外出先のiPhoneからTailscale経由でSSHするためのOpenSSH / Tailscaleは`bootstrap.sh`が導入する。tmux本体はNix、SSH時の自動attachは`.zshrc`。

## 技術スタック
- Nix / home-manager standalone（Ubuntu環境の宣言的管理。`flake.nix` + `nix/`。CLIツールとGNOMEデスクトップのdconf設定の両方を含む）
- Zsh（Oh My Zsh + Powerlevel10k。プロンプト設定は`zsh/.p10k.zsh`。本体は`bootstrap.sh`が導入し、あえてNix管理外）
- tmux（`packages.nix`。iPhoneからのSSH時に`.zshrc`が自動attach。切断してもセッションが残る）
- VSCode / Cursor（`vscode/`配下の共通設定をhome-manager経由で書き込み可能リンクし、拡張機能をactivation時に自動導入）
- direnv / nix-direnv（`nix/home.nix`のhome-manager設定で導入。`.envrc`のあるプロジェクトディレクトリでflakeのdevShellを自動ON/OFF）
- Bash（`bootstrap.sh`、`.claude/setup.sh`、`.claude/hooks/`配下のシェルスクリプト）
- Claude Code（`settings.json` / `CLAUDE.md` / Skills / Hooksによるグローバル設定管理）
- Grok CLI（xAI。`grok/config.toml`と`grok/AGENTS.md`をhome-manager経由で書き込み可能リンク。本体は`bootstrap.sh`が公式インストーラーで導入）
- Web Push通知（dotfiles内蔵の送信スクリプト`claude-notify/send-push.mjs`が、Stop/Notification時にiPhoneへプッシュ通知。受信側PWAは別リポジトリ`claude-notify-mobile`をVercelで配信。Node.js + `web-push` + `jq`）
- GitHub Actions（`.github/workflows/`配下で共通ワークフローを管理し、他リポジトリへ配布）
- GitHub CLI（`gh`、`/pr`スキル内でPR作成に使用）

## ディレクトリ構成
```
dotfiles/
├── README.md
├── CLAUDE.md              # リポジトリのアーキテクチャ・禁止事項・検証（Claude Code向け）
├── flake.nix              # Nix環境のエントリポイント（home-manager standalone）
├── flake.lock             # パッケージバージョンの固定（`nix flake update`後は必ずコミット）
├── bootstrap.sh           # 新しいUbuntuマシンの1コマンドセットアップ
├── nix/
│   ├── README.md          # Nix運用の詳細ドキュメント
│   ├── packages.nix       # CLIツール（git・gh・vim・Node.js等。Nixで管理）
│   ├── home.nix           # home-manager設定（zsh・gitconfig・Grok・VSCode/Cursorのリンク、VSCode IME用起動ラッパー、拡張機能、direnv、.claude/、claude-notify依存、ghエイリアス、GNOME Terminal見た目、既定ブラウザ）
│   ├── keyboard.nix       # GNOMEのキーボード設定（JIS配列・IME切り替え・キーリピート delay=250ms・TUI向け embed-preedit-text=false）
│   └── desktop.nix        # GNOMEデスクトップ設定（テーマ・電源・キーバインド・Dock・ウィンドウボタン左上。VSCode側は vscode/）
├── git/
│   ├── README.md
│   └── .gitconfig         # gitconfigの実体（home.nixが~/.gitconfigへ書き込み可能リンク。user.name/emailは~/.gitconfig.localに手動配置）
├── grok/
│   ├── README.md
│   ├── config.toml        # Grok CLI（xAI）の設定実体（home.nixが~/.grok/config.tomlへ書き込み可能リンク）
│   └── AGENTS.md          # Grokのグローバル指示（Grok固有の補足のみ。共通ルールはClaude互換で.claude/CLAUDE.mdが読まれる）
├── vscode/
│   ├── README.md          # VSCode/Cursor共通設定の詳細ドキュメント（統合ターミナルの日本語IME含む）
│   ├── settings.json      # エディタ設定の実体（両エディタで共有）
│   ├── keybindings.json   # キーバインドの実体（両エディタで共有）
│   ├── code               # snap VSCodeのIME用起動ラッパー（home.nixが~/.local/bin/codeへリンク）
│   ├── extensions.txt     # 導入する拡張機能のIDリスト
│   └── install-extensions.sh # 拡張機能をVSCode/Cursorへ導入（activation時に自動実行）
├── commands/
│   ├── claude-code.md    # Claude Code組み込みスラッシュコマンド一覧（リファレンス）
│   └── private.md        # このリポジトリで使えるコマンド・スキルの個人用早見表
├── .github/
│   └── workflows/
│       └── delete-merged-branch.yml # PRマージ後にheadブランチを自動削除
├── zsh/
│   ├── .zshrc            # Oh My Zsh + Powerlevel10k、SSH時のtmux attach、direnv フック
│   ├── .bashrc           # 対話bashを即zshへexecする引き継ぎ用
│   ├── .p10k.zsh         # Powerlevel10kの見た目設定（macOS風の最小構成）
│   └── README.md
├── tmux/
│   ├── README.md         # SSH切断後もセッションを残す説明
│   └── .tmux.conf        # 256色・履歴（home.nix が ~/.tmux.conf へリンク）
├── claude-notify/         # iPhoneプッシュ通知の送信スクリプト（.claude/hooks/notify.sh から呼ばれる）
│   ├── README.md
│   ├── send-push.mjs     # Web Push送信本体（VAPID署名。設定は ~/.claude/claude-notify.json）
│   ├── package.json      # 依存は web-push のみ
│   └── pnpm-lock.yaml    # node_modules は activation 時に自動導入（gitignore）
├── ssh-tailscale/         # iPhoneからTailscale経由SSH（OpenSSH + Tailscale。本体はNix管理外）
│   ├── README.md         # iPhone側の接続手順とUbuntu側の残作業
│   └── setup.sh          # OpenSSH / Tailscale を冪等に導入（bootstrap と home-manager switch から実行）
└── .claude/
    ├── CLAUDE.md          # 全プロジェクト向けグローバル指示（言語・Git・Nix・検証）。プロジェクト固有は書かない
    ├── rules/orchestration.md # Claude Code 専用のモデル振り分け（Grok は読まない）
    ├── settings.json      # フック・permissions・languageなどの設定
    ├── setup.sh           # .claude/ 配下を ~/.claude へシンボリックリンク
    ├── claude-notify.example.json # iPhoneプッシュ通知設定のテンプレート（~/.claude/claude-notify.json へコピー）
    ├── hooks/
    │   ├── notify.sh      # Stop/Notification時にiPhoneへWeb Push通知
    │   └── pr-mode.sh     # /pr 実行中だけgit操作を自動許可
    ├── skills/
    │   ├── pr/SKILL.md            # /pr スキル
    │   ├── readme/SKILL.md        # /readme スキル
    │   ├── clean-branches/SKILL.md # /clean-branches スキル
    │   └── nix-setup/SKILL.md     # /nix-setup スキル
    └── README.md
```

## セットアップ
### 新しいUbuntuマシンのセットアップ（Nix）
```zsh
curl -fsSL https://raw.githubusercontent.com/seino914/ubuntu-dotfiles/main/bootstrap.sh | bash
```
`bootstrap.sh`が前提パッケージ（git・curl・zsh）の確認、Nix（Determinate Systemsインストーラー）の導入、`~/Dev/kaishi/ubuntu-dotfiles`へのクローン、`flake.nix`の`username`書き換え、home-managerの初回適用（tmux・`.tmux.conf`・SSH時の自動attachを含む）、ログインシェルのzshへの変更、Oh My ZshとPowerlevel10kの導入、Claude Code CLIの導入、さらにNixで管理できないGUIアプリ・IME（ibus-mozc・mozc-utils-gui・VSCode・Slack・Google Chrome）のapt/snap経由での導入、Grok CLIの導入、OpenSSHサーバーとTailscaleの導入までを1コマンドで行う（冪等。sudoが使えない環境では該当ステップを警告してスキップする）。初回の `home-manager switch` は VSCode 導入より先に走るため、拡張機能は bootstrap 完了後にもう一度 `home-manager switch` する。手動で必要な残作業（`~/.gitconfig.local`の配置、`~/.claude/claude-notify.json`の配置、Docker Engineの導入、`sudo tailscale up`、iPhoneのTailscale / SSHアプリ、各アプリへのサインイン等）は[nix/README.md](/nix/README.md)と[ssh-tailscale/README.md](/ssh-tailscale/README.md)を参照。tmuxは追加作業なし（SSHした時点で入る）。

### Nix環境の適用・更新（2回目以降）
```zsh
home-manager switch --flake ~/Dev/kaishi/ubuntu-dotfiles#ubuntu
```
設定ファイル（`flake.nix` / `nix/*.nix`）を変更した後に実行する。sudoは不要だが環境そのものを書き換えるため、Claude Codeからは実行せずユーザーが手動で行う。

### Claude Code設定の反映
```zsh
bash ~/Dev/kaishi/ubuntu-dotfiles/.claude/setup.sh
```
`.claude/`配下の全ファイルが`~/.claude`へシンボリックリンクされる（`home-manager switch`時にはactivationからも自動実行される）。

### zsh設定の反映
```zsh
source ~/.zshrc
```

## コマンド
### Nix環境
```zsh
# 適用（設定ファイル変更後）
home-manager switch --flake ~/Dev/kaishi/ubuntu-dotfiles#ubuntu

# 初回（home-manager未導入時）
nix run home-manager/master -- switch --flake .#ubuntu -b hm-backup

# パッケージのバージョン更新（実行後、flake.lock を必ずコミット）
nix flake update
```

### Claude Codeスキル
- `/pr`：ユーザーが `/pr` と打ったときだけ、変更をコミットしブランチをpushしてGitHubへPull Requestを作成する（「PRを出して」では起動しない）
- `/readme`：READMEをコードベースの現状に合わせて更新（なければ新規作成）する
- `/clean-branches`：ローカルブランチのうちmain・develop以外を削除して整理する
- `/nix-setup`：新規プロジェクトの開発環境をNixのdevShell + direnvでセットアップする

### セットアップスクリプト
- `bash .claude/setup.sh`：`.claude/`配下を`~/.claude`へシンボリックリンク
- `bash vscode/install-extensions.sh`：`vscode/extensions.txt`の拡張機能をVSCode/Cursorへ導入（`home-manager switch`時にも自動実行される。冪等）
- OpenSSH / Tailscale：`bootstrap.sh` と `home-manager switch` の両方で `ssh-tailscale/setup.sh` が自動実行される（ログインだけ `sudo tailscale up` が手動。iPhone側は [ssh-tailscale/README.md](/ssh-tailscale/README.md)）

### GitHub Actionsワークフローのコピー
導入したいリポジトリのルートに移動して、そのまま実行する：
```zsh
mkdir -p .github/workflows
cp ~/Dev/kaishi/ubuntu-dotfiles/.github/workflows/*.yml .github/workflows/
```

### コマンドリファレンス（[commands](/commands/private.md)）
- `commands/claude-code.md`：Claude Code組み込みスラッシュコマンドの一覧表
- `commands/private.md`：このリポジトリで使えるスキル・コマンドの個人用早見表

## 設定一覧
- [Nix](/nix/README.md)
- [zsh](/zsh/README.md)
- [VSCode](/vscode/README.md)
- [git](/git/README.md)
- [Grok](/grok/README.md)
- [Claude Code](/.claude/README.md)
- [claude-notify](/claude-notify/README.md)
- [iPhoneからSSH（Tailscale）](/ssh-tailscale/README.md)
- [tmux](/tmux/README.md)
