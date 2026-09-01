# コマンド

ルート README のコマンド節からの個人用早見表。詳細・設計理由は各ディレクトリの README を見る。

## Claude Code

### Skills
```
/pr
/readme
/clean-branches
```

## Codex

設定実体は `codex/`。スキルは `.claude/skills/` を共有（`$pr` / `$readme` / `$clean-branches`）。導入後に CLI で `/hooks` を開き、dotfiles 由来のフックを trust する。

## Github Workflow

```zsh
mkdir -p .github/workflows
cp ~/Dev/kaishi/ubuntu-dotfiles/.github/workflows/*.yml .github/workflows/
```

## zsh

```zsh
source ~/.zshrc
```

## PCセットアップ

### 初回

```zsh
curl -fsSL https://raw.githubusercontent.com/seino914/ubuntu-dotfiles/main/bootstrap.sh | bash
```

### 2回目以降

```zsh
home-manager switch --flake ~/Dev/kaishi/ubuntu-dotfiles#ubuntu
```

### 手動残作業（新マシン）

- `~/.gitconfig.local` に `user.name` / `user.email`
- `~/.claude/claude-notify.json`（iPhone通知を使う場合）
- Docker Engine + `docker` グループ
- `gh auth login`、SSH鍵、各アプリへのサインイン

### パッケージの更新

```zsh
cd ~/Dev/kaishi/ubuntu-dotfiles
nix flake update
home-manager switch --flake .#ubuntu
```


