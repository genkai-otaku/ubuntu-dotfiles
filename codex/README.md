# Codexの設定とハーネス

Codex CLIとdesktopの個人用設定。Claude Codeと共通の指示・スキル手順を使い、コミット制限、削除の事故防止、dotfiles変更後の検証をCodexのフックへ接続する。

## 管理するファイル

| 実体 | 配布先・役割 |
| --- | --- |
| `config.toml` | `~/.codex/config.toml`。ユーザーのモデル・reasoning effort、`on-request` と `auto_review` と `workspace-write`、ネットワーク設定 |
| `hooks.json` | `~/.codex/hooks.json`。PR起動判定、シェル操作のガード、変更と検証の記録、終了時の検証ゲート |
| `hooks/guard.sh` | `~/.codex/hooks/guard.sh`。明示的なPRモード以外でcommit・push・PR操作を拒否 |
| `hooks/harness.sh` | `~/.codex/hooks/harness.sh`。Claudeの事故防止・検証ゲートをCodexのイベントへ接続 |
| `skills/*` | `~/.agents/skills/*`。Codex用の入口から `.claude/skills/` の共通手順を読む |
| `prompts/pr.md` | `~/.codex/prompts/pr.md`。旧 `/prompts:pr` 入口 |
| `../ai/core.md`・`../ai/codex.md` | `bash ai/install.sh` が `~/.codex/AGENTS.md` を連結生成 |

設定とフックのリンクがCodexなどに実体ファイルで置き換えられた場合は、`nix/home.nix` の `captureCodexConfigWrites` が次のswitch前に変更を取り込む。モデルとreasoning effortはユーザーが決め、Claude専用のモデル名やAgent設定は移植しない。

## 反映と使い方

```zsh
bash .claude/tests/run.sh
nix eval --raw .#homeConfigurations.ubuntu.activationPackage.drvPath
bash ai/install.sh

# 設定・フック・スキルのリンク追加を反映する操作はユーザーが実行する
home-manager switch --flake ~/Dev/kaishi/ubuntu-dotfiles#ubuntu
```

新しいCodexチャットを開始し、`/hooks` で各フックの内容を確認して信頼する。未信頼の非管理フックは実行されず、定義変更後は再確認が必要。信頼状態やハッシュはエージェントが書き換えない。[公式Hooks](https://learn.chatgpt.com/docs/hooks)

操作の承認は既定で `approvals_reviewer = "auto_review"` により自動レビューへ回す。再起動後の新しいチャットで反映を確認する。フックの信頼確認は別途ユーザーが行う。[公式Auto-review](https://learn.chatgpt.com/docs/sandboxing/auto-review)

| Claude Codeの入口 | Codexの入口 |
| --- | --- |
| `/pr` | `$pr`（旧 `/prompts:pr` も維持） |
| `/readme` | `$readme` |
| `/nix-setup` | `$nix-setup` |
| `/git-pull` | `$git-pull` |
| `/clean-branches` | `$clean-branches` |

Codexは `~/.agents/skills` のシンボリックリンクを読み、スキルは `$名前` で明示起動できる。PRだけは明示起動に限定し、自然言語の「PRを出して」では起動しない。旧custom promptは非推奨なので、新しい入口にはスキルを使う。[公式Skills](https://learn.chatgpt.com/docs/build-skills)、[公式Custom Prompts](https://learn.chatgpt.com/docs/custom-prompts)

CodexのPreToolUseは拒否専用で、Claudeのフックによる自動承認は使えない。CLI 0.162.1の `exec_command` はフックの `tool_input` に `command` だけを渡し、`sandbox_permissions` は渡さない。そのため確認対象を `require_escalated` で再試行してもフックが承認情報を受け取れず、拒否が続く。対象のコマンドと理由を示し、ユーザーに手動実行を依頼する。[公式実装](https://github.com/openai/codex/blob/rust-v0.162.1/codex-rs/core/src/tools/handlers/unified_exec/exec_command.rs#L514-L524)

`sandbox_permissions` がフックへ届く環境では、確認対象を理由付きで `require_escalated` に再試行し、Codexの承認UIへ渡す互換動作を維持する。拒否対象は停止し、別の書き方やツールで迂回しない。`clean-branches` の未マージブランチ強制削除も、対象の一覧を示してユーザーに明示的な確認を求め、環境に応じて手動実行の依頼または承認UIへの再試行を行う。

PRモードは起動したターンだけ有効。`Stop` で終了した後は、検証ゲートによって続行する場合も `$pr` の再起動が必要になる。PR手順では検証を先に済ませ、commit・push・PR操作が終わるまでターンを終えない。

## CLIとdesktopの違い

CLI 0.162.1では `hooks`・`multi_agent` は既定で有効。機能を使うためだけの重複設定は追加しない。[公式設定リファレンス](https://learn.chatgpt.com/docs/config-file/config-reference)

desktopは独自のランタイム、承認UI、pluginsを持つ。`config.toml` のdesktop・marketplace・plugin・MCP設定はdesktopが更新することがあり、CLIの設定を直しただけで実行中のdesktopチャットへ全て反映されるとは扱わない。新しいチャットでスキル一覧と `/hooks` を確認する。CLIのシェルイベントに接続したフックが、別のMCPツールやクラウド実行にも適用されるとは扱わない。共通指示とプロジェクトの `AGENTS.md` は各環境で維持する。

## Ubuntuのサンドボックスエラー

`bwrap: setting up uid map: Permission denied` が出ると、通常の読み取り・検証まで承認が必要になる。2026-10-13の実機ではUbuntu 24.04.5、`/usr/bin/bwrap` は存在するが `kernel.apparmor_restrict_unprivileged_userns=1` で、`bwrap-userns-restrict` のAppArmorプロファイルが配置されていなかった。

Codexは `PATH` で最初に見つかる `bwrap` を使う。Ubuntu 24.04では公式手順に沿ってbubblewrap用のAppArmorプロファイルを追加し、`workspace-write` を維持して通常操作を動かす。以下はOSへの変更なのでユーザーが実行する。[公式Sandbox](https://learn.chatgpt.com/docs/sandboxing)

```zsh
sudo apt update
sudo apt install bubblewrap apparmor-profiles apparmor-utils
sudo install -m 0644 \
  /usr/share/apparmor/extra-profiles/bwrap-userns-restrict \
  /etc/apparmor.d/bwrap-userns-restrict
sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict
```

反映後はCodexを起動し直し、`codex sandbox -- true` と、通常の読み取り・検証が承認なしで動くことを確認する。プロファイルがパッケージに含まれなければその時点で止めてOS側を確認する。
