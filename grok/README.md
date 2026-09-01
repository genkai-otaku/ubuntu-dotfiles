# Grok CLI 設定

Grok CLI（xAI）の設定実体。適用は [nix/home.nix](../nix/home.nix) が担い、`~/.grok/config.toml` と `~/.grok/AGENTS.md` へ書き込み可能なシンボリックリンクを張る。本体は [bootstrap.sh](../bootstrap.sh) が公式インストーラーで導入する（Claude Code と同様、常に最新版を使うためあえてNix管理外）。

## ファイル構成

| ファイル | 役割 |
|---|---|
| [`config.toml`](config.toml) | Grok CLI の設定実体（UI・marketplace・権限モード） |
| [`AGENTS.md`](AGENTS.md) | Grok 向けグローバル指示。**Grok固有の補足のみ** |

## AGENTS.md に書くこと / 書かないこと

言語（常に日本語）・Git操作の制限・Nix運用などの共通ルールは、Claude互換モード（デフォルト有効）が読む `~/.claude/CLAUDE.md` に任せる。同じ内容をここに複製しない。書くのは `spawn_subagent` / explore・plan・general-purpose の使い分けと、CLAUDE.md のモデル名（Fable / Sonnet / Opus）を使わないこと。ホーム指示は `~/.grok/AGENTS.md` のあと `~/.claude/CLAUDE.md` が載るので、モデル節の衝突は CLAUDE.md 側でも「Claude Code 専用」と書いて打ち消す。

## 管理対象外

`~/.grok/` 直下の次は秘密情報・キャッシュ・セッションなのでリポジトリに置かない。

- `auth.json`（認証）
- `sessions/` / `logs/` / `marketplace-cache/` / `worktrees.db` などランタイム生成物
- `trusted_folders.toml`（このマシンで信頼したディレクトリ）

## 権限モードと `/pr` フロー

`config.toml` の `permission_mode = "always-approve"` は確認ダイアログを出さない設定。その代わり `pr-mode.sh` の `PreToolUse` が、`/pr` 中以外の `git commit` / `git push` / `gh pr create` / `gh pr merge` を deny する。`/pr` の検出は Grok に無い `UserPromptExpansion` の代わりに `UserPromptSubmit`（先頭 `/pr`、またはスキル本文の `<!-- pr-mode-enable -->`）で行う。stdin は camelCase、イベント名は `GROK_HOOK_EVENT`。`/pr` 中は確認なしでコマンドを実行してよい。

## VSCode 統合ターミナルの日本語IME

Grok を VSCode の統合ターミナルで使うと、Mozc の変換中プレビューが確定扱いされ「この」が「ｋこｎこのこの」になることがある。Grok 側の設定ではなく ibus / エディタ側の問題。本体の対策は [`../nix/keyboard.nix`](../nix/keyboard.nix) の `embed-preedit-text = false`。経緯と補助設定は [`../vscode/README.md`](../vscode/README.md) の「統合ターミナルの日本語IME」を見る。

## サブエージェントのモデル

`[subagents.models] explore = "grok-4.5"` で調査だけ親より軽いモデルへ振る。plan / general-purpose は未設定なので親（いまは grok-4.6）を継承する。

## リンクが実体化したとき

Grok 自身が `config.toml` へ書き込む。書き込み可能リンクなら変更はリポジトリ側に届くが、シンボリックリンクを実体ファイルで置き換える場合がある。`home.nix` の `captureGrokConfigWrites` が `home-manager switch` の直前に、実体の方が新しければリポジトリへ取り込み、`force = true` でリンクに戻す。
