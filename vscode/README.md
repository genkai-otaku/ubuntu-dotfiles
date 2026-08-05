# VSCode / Cursor 共通設定

VSCodeとCursorの設定の**実体**を置くディレクトリ。CursorはVSCodeのフォークで設定ファイルの形式・配置が同じため、両エディタでここの同一ファイルを共有する。

適用は [nix/home.nix](../nix/home.nix) が担い、各エディタのUserディレクトリ（`~/.config/{Code,Cursor}/User/`）からここへの**書き込み可能なシンボリックリンク**を張る。そのため、どちらのエディタのUIから設定を変更してもこのディレクトリのファイルに直接書き込まれ、git差分として現れる。

## ファイル構成

| ファイル | 役割 |
|---|---|
| [`settings.json`](settings.json) | エディタ設定の実体（両エディタで共有） |
| [`keybindings.json`](keybindings.json) | キーバインドの実体（両エディタで共有） |
| [`extensions.txt`](extensions.txt) | 導入する拡張機能のIDリスト（1行1ID） |
| [`install-extensions.sh`](install-extensions.sh) | `extensions.txt` の拡張機能をVSCode/Cursorへ導入するスクリプト。`home-manager switch` 時にhome-manager activationから自動実行される |

## 仕組みと設計理由

- エディタ本体はNix管理外（apt・snap・公式debパッケージ等で手動導入）。そのためhome-managerの `programs.vscode` モジュール（Nix製VSCodeの導入が前提）は使わず、設定ファイルは `mkOutOfStoreSymlink`、拡張機能はactivationスクリプトで管理する
- リンクは書き込み可能。home-manager標準のstore管理だと設定が読み取り専用になり、エディタのUIから変更できなくなるため、`~/.zshrc` と同じ方式を採る
- 拡張機能は「ファイル」ではなく「インストール状態」なのでリンクでは管理できない。`install-extensions.sh` がリストとの差分だけをインストールする。エディタ本体が未導入ならそのエディタをスキップし、次回のswitchで冪等にリトライされる
- activation環境のPATHに依存しないよう、CLIは既知の絶対パス候補（deb版 `/usr/bin/code`・snap版 `/snap/bin/code`・`~/.local/bin/cursor` 等）を先に探し、見つからなければ `command -v` にフォールバックする
- キーバインドはmacOS版dotfilesと同内容だが、チャット新規作成のみ `cmd+l` → `alt+l` に変更している（LinuxのSuper+LはGNOMEの画面ロックと衝突するため）

## よくある操作

### 設定・キーバインドの変更

エディタのUIから変更するだけ。git差分として現れるので確認してコミットする。適用コマンドは不要。

### 拡張機能の追加

エディタからインストールし、`extensions.txt` へIDを追記する。次回の `home-manager switch` でもう片方のエディタと新しいマシンに自動導入される。

### 拡張機能の削除

エディタからアンインストールし、`extensions.txt` から該当行を削除する。**リストから消しても既存環境からは自動でアンインストールされない**（新しい環境に入らなくなるだけ）。

## 注意

- 設定は両エディタで完全共有。片方だけに効かせる運用は想定していない（必要なら `home.nix` の `editorUserFiles` を分割する）
- `home.nix` 側の `force = true` は初回適用時に既存の実体ファイルをリンクへ置き換えるためのもの。別のマシンへ初適用する際、そのマシン固有の設定があれば先にこのディレクトリへ取り込んでおくこと
- このディレクトリのファイルはflake評価時には読まれず、適用時に絶対パスで参照されるだけ。追加・変更に `git add` は不要だが、新しいマシンへ配るにはコミットとpushが必要（`bootstrap.sh` はGitHub上のmainをクローンするため）
- 新しいUbuntuマシンではエディタ本体の導入が手動のため、`bootstrap.sh` 実行時点でエディタが未導入なら拡張機能の導入はスキップされる。エディタを導入した後にもう一度 `home-manager switch` を実行すれば導入される
