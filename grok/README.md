# Grok CLI 設定

Grok CLI（xAI）の設定実体。適用は [nix/home.nix](../nix/home.nix) が担い、`~/.grok/config.toml` と `~/.grok/AGENTS.md` へ書き込み可能なシンボリックリンクを張る。本体は [bootstrap.sh](../bootstrap.sh) が公式インストーラーで導入する（Claude Code と同様、常に最新版を使うためあえてNix管理外）。

## ファイル構成

| ファイル | 役割 |
|---|---|
| [`config.toml`](config.toml) | Grok CLI の設定実体（UI・marketplace・権限モード） |
| [`AGENTS.md`](AGENTS.md) | Grok 向けグローバル指示。**Grok固有の補足のみ** |

## AGENTS.md に書かないこと

言語（常に日本語）・Git操作の制限・Nix運用などの共通ルールは、Claude互換モード（デフォルト有効）が読む `~/.claude/CLAUDE.md` に任せる。同じ内容をここに複製しない。書くのは `spawn_subagent` / explore・plan・general-purpose の使い分けなど、Grok固有の読み替えだけ。

## 管理対象外

`~/.grok/` 直下の次は秘密情報・キャッシュ・セッションなのでリポジトリに置かない。

- `auth.json`（認証）
- `sessions/` / `logs/` / `marketplace-cache/` / `worktrees.db` などランタイム生成物
- `trusted_folders.toml`（このマシンで信頼したディレクトリ）

## 権限モードと `/pr` フロー

`config.toml` の `permission_mode = "always-approve"` は Grok 側の確認ダイアログを出さない設定。Claude Code の `permissions.ask` と `hooks/pr-mode.sh`（確認ダイアログを `/pr` 中だけ自動承認する層）は Grok では効かない。Grok での git commit / push / PR作成の抑止は `~/.claude/CLAUDE.md` とこの `AGENTS.md` の指示に依存する。

## VSCode 統合ターミナルの日本語IME

Grok を VSCode の統合ターミナルで使うと、Mozc の変換中プレビューが確定扱いされ「この」が「ｋこｎこのこの」になることがある。Grok 側の設定ではなく ibus / エディタ側の問題。本体の対策は [`../nix/keyboard.nix`](../nix/keyboard.nix) の `embed-preedit-text = false`。経緯と補助設定は [`../vscode/README.md`](../vscode/README.md) の「統合ターミナルの日本語IME」を見る。

## リンクが実体化したとき

Grok 自身が `config.toml` へ書き込む。書き込み可能リンクなら変更はリポジトリ側に届くが、シンボリックリンクを実体ファイルで置き換える場合がある。`home.nix` は `force = true` なので次回 `home-manager switch` でリンクに戻る。実体側に新しいキーが増えていたら、switch する前にリポジトリの `config.toml` へ取り込んでおく。
