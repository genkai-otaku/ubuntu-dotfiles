# Codex CLI 設定

Codex CLI（OpenAI）の設定実体。適用は [nix/home.nix](../nix/home.nix) が担い、`~/.codex/config.toml`・`~/.codex/AGENTS.md`・`~/.codex/hooks.json`・`~/.codex/hooks/run.sh` へ書き込み可能なシンボリックリンクを張る。スキルは `.claude/skills/` の各ディレクトリを `~/.codex/skills/<name>` へディレクトリ単位でリンクする（Codex は SKILL.md ファイルのシンボリックリンクを無視するため）。本体のインストールは bootstrap の対象にしない（使うとき公式インストーラーで入れる）。

## ファイル構成

| ファイル | 役割 |
|---|---|
| [`config.toml`](config.toml) | Codex CLI の設定実体（承認ポリシー・サンドボックス・reasoning） |
| [`AGENTS.md`](AGENTS.md) | Codex 向けグローバル指示。**Codex固有の補足のみ** |
| [`hooks.json`](hooks.json) | SessionStart / `/pr` ガード / iPhone 通知のフック定義 |
| [`hooks/run.sh`](hooks/run.sh) | `.claude/hooks/` の共有スクリプトを Codex 向けに呼ぶラッパー |

## AGENTS.md に書くこと / 書かないこと

言語（常に日本語）・Git操作の制限・Nix運用などの共通ルールは `~/.claude/CLAUDE.md` に任せる。同じ内容をここに複製しない。SessionStart フックが CLAUDE.md を developer context に載せる。書くのは組み込みエージェント（`explorer` / `worker` / `default`）の使い分けと、CLAUDE.md のモデル名（Fable / Sonnet / Opus）を使わないこと。

## 管理対象外

`~/.codex/` 直下の次は秘密情報・キャッシュ・セッションなのでリポジトリに置かない。

- `auth.json`（認証）
- `history.jsonl` / `log/` / `sessions/` などランタイム生成物
- `tmp/` / `models_cache.json` など
- プロジェクト信頼情報（`config.toml` の `[projects."..."]` はマシン固有。リポジトリの `config.toml` には書かない。`home.nix` の `captureCodexConfigWrites` が取り込み時に除去する）

## 権限モードと `/pr` フロー

`config.toml` の `approval_policy = "never"` と `sandbox_mode = "danger-full-access"` は確認ダイアログを出さない設定（Grok の `permission_mode = "always-approve"` に相当）。その代わり `hooks.json` が `.claude/hooks/pr-mode.sh` を呼び、`/pr` 中以外の `git commit` / `git push` / `gh pr create` / `gh pr merge` を PreToolUse で deny する。`/pr` の検出は Claude に無い `UserPromptExpansion` の代わりに `UserPromptSubmit`（先頭 `/pr` または `$pr`、またはスキル本文の `<!-- pr-mode-enable -->`）。stdin は Claude と同じ snake_case。ラッパーが `CODEX_HOOK=1` を立てて Grok と区別する。`/pr` 中は確認なしでコマンドを実行してよい。

Codex は非管理フックを初回（および定義変更時）に信頼するまでスキップする。導入後に CLI で `/hooks` を開き、このリポジトリ由来のフックを trust する。

## スキル

`.claude/skills/`（`pr` / `readme` / `clean-branches`）を `~/.codex/skills/` へディレクトリリンクする。実体は Claude と共有なので、スキル本文は片方だけ編集する。Codex の明示起動は `$pr`（スラッシュの `/pr` でも UserPromptSubmit が検出する）。

## VSCode 統合ターミナルの日本語IME

Codex を VSCode の統合ターミナルで使うと、Mozc の変換中プレビューが確定扱いされ「この」が「ｋこｎこのこの」になることがある。Codex 側の設定ではなく ibus / エディタ側の問題。本体の対策は [`../nix/keyboard.nix`](../nix/keyboard.nix) の `embed-preedit-text = false`。経緯と補助設定は [`../vscode/README.md`](../vscode/README.md) の「統合ターミナルの日本語IME」を見る。

## リンクが実体化したとき

Codex 自身が `config.toml` へ書き込む。書き込み可能リンクなら変更はリポジトリ側に届くが、シンボリックリンクを実体ファイルで置き換える場合がある。`home.nix` の `captureCodexConfigWrites` が `home-manager switch` の直前に、実体の方が新しければリポジトリへ取り込み（その際 `[projects]` は落とす）、`force = true` でリンクに戻す。リンク経由で `[projects]` がリポジトリへ届いていた場合も同じ処理で除去する。
