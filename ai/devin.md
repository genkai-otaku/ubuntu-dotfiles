# Devin 固有の補足

設定は `~/.config/devin/config.json`（モデル・`permissions`）。宣言設定は dotfiles の `devin/config.json` に置き、home-manager がホーム側の実ファイルへマージする（`org_id`・セットアップ状態はホーム側だけで保持）。Claude Code / Grok の `settings.json`・Hooks は動かない。

- `permissions` の `ask` に落ちた操作はユーザーの承認を得てから実行する。`deny`（`sudo`・`gh pr merge`）は迂回しない。force push も迂回しない。プロジェクト側で緩める `.devin/config.json` を勝手に作らない
- Exec ルールは語単位の前方一致。`git push --force` / `git push --force-with-lease` / `git push -f` から始まるコマンドは deny だが、`git push origin --force` のようにリモート等が先に来る形はその deny に一致せず、`git push` の ask になる。承認を得ても force push は実行しない
- `/pr` に相当する明示指示がないターンでは commit / push / PR 操作をしない（成果物は未コミットで残して報告する）
- Devin のクラウド側セッションへ、このマシンの秘密情報や `~/.config` の認証ファイルを送らない
