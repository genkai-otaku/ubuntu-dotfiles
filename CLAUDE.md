# CLAUDE.md

このファイルは **このリポジトリ専用**（プロジェクト指示）。全プロジェクト向けは `~/.claude/CLAUDE.md`（実体 `.claude/CLAUDE.md`）。プロジェクト固有のビルド手順・ディレクトリ説明は各リポジトリの CLAUDE.md に書く。ここへ足さない。

## リポジトリの性質

Ubuntu用の個人dotfiles。ビルド・lint・テストは無い。管理対象：

- `flake.nix` + `nix/` — home-manager standalone（CLI と GNOME dconf）。`keyboard.nix` の ibus `embed-preedit-text = false` は戻さない。`bootstrap.sh` が新マシンの1コマンドセットアップ
- `vscode/` — VSCode / Cursor 共通設定。書き込み可能リンク（詳細 `vscode/README.md`）
- `.claude/` — Claude Code の**グローバル**設定実体。全プロジェクトの毎セッションに載るので、プロジェクト固有は書かない
- `git/` — gitconfig 実体（`user.name` / `user.email` は `~/.gitconfig.local`）
- `grok/` — Grok CLI 設定実体。共通ルールは `.claude/CLAUDE.md`。本体は bootstrap
- `zsh/` — Oh My Zsh + Powerlevel10k（本体は bootstrap。Nix 管理外）
- `claude-notify/` — iPhone Web Push の送信側
- `.github/workflows/` — 他リポジトリへコピーするテンプレート。このリポジトリの PR にも発火する
- `commands/` — 早見表。`.claude/commands/` ではない

## 最重要：`.claude/` は全プロジェクトに即反映

`~/.claude/*` はこの `.claude/` へのリンク。編集するとコミット前でも全セッションの挙動が変わる。`/model` や `/config` の変更もこの `settings.json` に未コミット差分として出る。

## グローバルに置くもの / 置かないもの

毎回のコンテキストに載る（Claude: [memory](https://code.claude.com/docs/en/memory)、Grok: [project rules](https://docs.x.ai/docs/build/features/project-rules)）。「消したらミスするか」だけ残す。

| 置く | 置かない（各プロジェクト側） |
|---|---|
| 日本語、`/pr`、Nix グローバルを汚さない、検証の義務 | ビルド/テストコマンド、ディレクトリ構成、言語の標準規約 |
| 個人スキル（`/pr` `/readme` `/nix-setup` `/clean-branches`） | そのリポジトリ専用のワークフロー |
| Claude 専用モデル振り分けは `.claude/rules/` | Grok に読ませる共通ルール（`compat.claude.rules = false`） |

## やってはいけないこと

- `.claude/` の処理を home-manager 標準管理へ移行する — `setup.sh` のセルフヒーリング（Issue #40857）は再現できない
- `editorUserFiles` の `force = true` を外す
- `username` ハードコードを動的取得にする — flake は環境変数を読めない
- direnv フックを `enableZshIntegration` に置き換える — `~/.zshrc` は mkOutOfStoreSymlink
- `claude-code` / Grok CLI を Nix 管理に入れる
- `home-manager switch` を実行する — 検証後にユーザーへ依頼
- `~/.claude/claude-notify.json` を読む・コミットする
- /pr 四層のうち一層だけ変える
- `embed-preedit-text` を `true` に戻す
- `window.titleBarStyle` / `menuStyle` / `menuBarVisibility` を片方だけ変える
- `grok/AGENTS.md` に共通ルールを重複させる
- `user.name` / `user.email` をリポジトリに書く
- `.claude/rules/` に共通ルールを書く — Grok は読まない

## 編集時

- 構成名は `ubuntu` 固定。`--flake <リポジトリ>#ubuntu`
- flake は git 追跡ファイルだけ認識する。`.nix` 追加は `git add`。`vscode/` は例外だが配るには push
- `.claude/` の追加・削除は `bash .claude/setup.sh`（switch 時にも実行）
- コマンドは `README.md`

## 変更後の検証（switch はしない）

```zsh
nix eval --raw .#homeConfigurations.ubuntu.activationPackage.drvPath
jq empty .claude/settings.json
bash -n <スクリプト>
```

`nix eval` は評価まで。activation 失敗は switch でしか分からないので、その旨を添えて依頼する。

## /pr の四層

1. `skills/pr` の `disable-model-invocation: true`
2. `.claude/CLAUDE.md` の禁止指示
3. `settings.json` の `permissions.ask`
4. `hooks/pr-mode.sh`（Claude は PermissionRequest で許可/拒否。Grok は PreToolUse で deny。`gh pr merge` は ask）

実装制約は `pr-mode.sh` 先頭コメント。

## claude-notify

`notify.sh` が Stop / Notification（`permission_prompt` のみ）から `send-push.mjs` を呼ぶ。失敗しても exit 0。Grok も同じ hooks（タイトルに「(Grok)」）。依存は switch 時の `pnpm install`。鍵は `~/.claude/claude-notify.json`（example のみリポジトリ）。
