# gitconfig

git のグローバル設定の実体。適用は [nix/home.nix](../nix/home.nix) が担い、`~/.gitconfig` へ書き込み可能なシンボリックリンクを張る（既存の実体ファイルを置き換えるため `force = true`）。

## ファイル構成

| ファイル | 役割 |
|---|---|
| [`.gitconfig`](.gitconfig) | リポジトリで管理する共通設定 |

## 管理している内容

- `init.defaultBranch = main`
- `diff.tool = vimdiff`（`vim` は `nix/packages.nix` で導入）
- `pager.branch = false`（`git branch` が短い出力でも全画面ページャーにならないようにする。zsh 側の `LESS=-FRX` と対）
- GitHub / gist の credential helper は PATH 上の `gh`（ユーザー名非依存）

## 個人情報はリポジトリに含めない

`user.name` / `user.email` は PUBLIC リポジトリに置かない。各PCで `~/.gitconfig.local`（git管理外）に `[user]` セクションを書き、`.gitconfig` 末尾の `include` で読み込む。

```ini
[user]
	name = Your Name
	email = you@example.com
```

新しいマシンではこのファイルの配置が手動残作業（[nix/README.md](../nix/README.md)）。

## gh のエイリアス

`gh alias set co "pr checkout"` は `~/.config/gh/config.yml` を gh 自身が書き換えるためファイルリンクにはせず、`home.nix` の activation で冪等に実行する。
