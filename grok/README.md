# Grok CLI 設定

Grok CLI（xAI）の設定実体。適用は [nix/home.nix](../nix/home.nix) が担い、`~/.grok/config.toml` と `~/.grok/AGENTS.md` へ書き込み可能なシンボリックリンクを張る。本体は [bootstrap.sh](../bootstrap.sh) が公式インストーラーで導入する（Claude Code と同様、常に最新版を使うためあえてNix管理外）。

## ファイル構成

| ファイル | 役割 |
|---|---|
| [`config.toml`](config.toml) | Grok CLI の設定実体（UI・marketplace・権限モード） |
| [`AGENTS.md`](AGENTS.md) | Grok 向けグローバル指示。**Grok固有の補足のみ** |

## AGENTS.md に書くこと / 書かないこと

言語・Git・Nix・検証・破壊的操作の許可ルートなどの共通ルールは、Claude互換モードが読む `~/.claude/CLAUDE.md` に任せる。同じ内容をここに複製しない。書くのは `spawn_subagent` の使い分け、Claude のモデル名を使わないこと、always-approve でも hook の ask / deny が効くこと。Claude 専用のモデル振り分けは `~/.claude/rules/` にあり、`config.toml` の `compat.claude.rules = false` で Grok は読まない。

## 管理対象外

`~/.grok/` 直下の次は秘密情報・キャッシュ・セッションなのでリポジトリに置かない。

- `auth.json`（認証）
- `sessions/` / `logs/` / `marketplace-cache/` / `worktrees.db` などランタイム生成物
- `trusted_folders.toml`（このマシンで信頼したディレクトリ）

## 権限モードと `/pr` フロー

`config.toml` の `permission_mode = "always-approve"` は通常の確認ダイアログを出さない設定。その代わり:

- `pr-mode.sh` の `PreToolUse` が、`/pr` 中以外の `git commit` / `git push` / `gh pr create` を deny する。force push は `/pr` 中でも deny。自動許可対象外の git 書き込みは ask（always-approve でも確認になる）
- `guard-destructive.sh` が致命的な削除を deny し、解釈できない削除は ask
- `settings.json` のシェル `ask` / `deny` ルールは always-approve でも効く（`gh pr merge`・`sudo`・グローバル install など）

`/pr` の検出は `UserPromptSubmit`（先頭 `/pr`、番兵 `<!-- pr-mode-enable -->`、または `skills/pr/SKILL.md` の H1）。stdin は camelCase、イベント名は `GROK_HOOK_EVENT`、ツール名は `run_terminal_command`（matcher `Bash` のエイリアスでも当たる）。

## VSCode 統合ターミナルの日本語IME

Grok を VSCode の統合ターミナルで使うと、Mozc の変換中プレビューが確定扱いされ「この」が「ｋこｎこのこの」になることがある。Grok 側の設定ではなく ibus / エディタ側の問題。本体の対策は [`../nix/keyboard.nix`](../nix/keyboard.nix) の `embed-preedit-text = false`。経緯と補助設定は [`../vscode/README.md`](../vscode/README.md) の「統合ターミナルの日本語IME」を見る。

## サブエージェントのモデル

`[subagents.models] explore = "grok-4.5"` で調査だけ親より軽いモデルへ振る。plan / general-purpose は未設定なので親（いまは grok-4.6）を継承する。

## リンクが実体化したとき

Grok 自身が `config.toml` へ書き込む。書き込み可能リンクなら変更はリポジトリ側に届くが、シンボリックリンクを実体ファイルで置き換える場合がある。`home.nix` の `captureGrokConfigWrites` が `home-manager switch` の直前に、実体の方が新しければリポジトリへ取り込み、`force = true` でリンクに戻す。
