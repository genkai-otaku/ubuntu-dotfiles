---
name: nix-setup
description: 新しいプロジェクトの開発環境をNixのdevShell + direnvでセットアップする。「開発環境を作って」「devShellを用意して」などの依頼、新規プロジェクトでツール・ランタイムの導入先が必要になったとき、/nix-setup 実行時に使用。
---

# 開発環境セットアップ（Nix + direnv）

新しいプロジェクトの開発環境を用意するときは、PCのグローバル環境を汚さないことを最優先とし、必要なツール・ランタイムはすべてNixのdevShellで宣言管理する。グローバルへのインストール（`apt install`・`npm install -g` 等）で済ませない。

## 手順

1. **必要なツールを決める**。プロジェクトの言語・パッケージ定義（`package.json`・`pyproject.toml` 等）から必要なランタイム・CLI を洗い出す。判断できなければ AskUserQuestion（Grok は `ask_user_question`）で確認する
2. **`flake.nix` の devShell（`pkgs.mkShell`）に宣言する**。既に `flake.nix` がある場合はその devShell に追記する。無ければ以下の雛形で作る（nixpkgs は dotfiles と同じ `nixpkgs-unstable` 系列）。既存の flake を勝手に作り直さない

   ```nix
   {
     description = "<プロジェクトの説明>";

     inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

     outputs =
       { nixpkgs, ... }:
       let
         system = "x86_64-linux";
         pkgs = import nixpkgs { inherit system; };
       in
       {
         devShells.${system}.default = pkgs.mkShell {
           packages = with pkgs; [
             # 必要なツール
           ];
         };
       };
   }
   ```

3. **direnv を併用する**。プロジェクトルートに `use flake` と書いた `.envrc` を作成し、`.gitignore` に `.direnv/` を追加する。`direnv allow` は内容を確認した `.envrc` に対してのみ実行する（direnv 本体と nix-direnv は dotfiles の home-manager で導入済み）
   - ユーザーの対話シェルでは `cd` で自動的に devShell が ON / OFF になる
   - **エージェントの Bash は非対話で direnv フックが効かない**。自分でツールを使うときは `nix develop -c <cmd>` または `direnv exec . <cmd>` で実行する
4. **git に追跡させる**。flake は git 追跡ファイルしか認識しないため、git 未初期化なら `git init` し、`git add flake.nix .envrc` する（ステージングで足りる。コミットはしない）。`flake.lock` も生成後に `git add` し、コミット対象にして再現性を担保する
5. **検証する**。`nix flake lock` で `flake.lock` を生成し、`nix develop -c <ツール> --version` で devShell 内からツールが使えることを確認する。評価エラーの検出には `nix flake check` も使える

## 報告

宣言したパッケージ、作成・変更したファイル（`flake.nix`・`.envrc`・`.gitignore`・`flake.lock`）、検証結果を簡潔に報告する。`direnv allow` を実行した場合はその旨も伝える。
