{
  config,
  lib,
  username,
  dotfilesPath,
  ...
}:
let
  # VSCode / Cursor は設定ファイルの形式・配置が同じ（CursorはVSCodeのフォーク）ため、
  # 両エディタとも vscode/ 配下の同一ファイルへの「書き込み可能なリンク」にする。
  # どちらのUIから変更しても同じ実体に書き込まれ、git差分として現れる。
  # エディタ本体はNix管理外（apt/snap等で手動導入）なので、programs.vscode
  # モジュール（Nix製VSCodeの導入が前提）は使わない。
  # force = true は初回適用時に既存の実体ファイルをリンクへ置き換えるために必要
  # （既存の内容はリポジトリへ取り込み済み）
  editorUserFiles = app: {
    ".config/${app}/User/keybindings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/vscode/keybindings.json";
      force = true;
    };
    ".config/${app}/User/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/vscode/settings.json";
      force = true;
    };
  };
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # home-managerの互換バージョン（変更しない）
  home.stateVersion = "25.05";

  # home-manager自身をhome-managerで管理する。
  # これにより2回目以降は `home-manager switch` コマンドが使えるようになる
  programs.home-manager.enable = true;

  # ~/.zshrc はリポジトリ実体への「書き込み可能なリンク」にする。
  # home-manager標準のstore管理だと読み取り専用になり、
  # リポジトリ側を直接編集して即反映という現在の運用ができなくなるため
  home.file = {
    ".zshrc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/zsh/.zshrc";
  }
  // editorUserFiles "Code" # VSCode
  // editorUserFiles "Cursor";

  # 拡張機能は「ファイル」ではなく「インストール状態」なのでリンクでは管理できない。
  # vscode/extensions.txt のIDリストを activation 時に VSCode / Cursor へ流し込む。
  # リストから消しても既存環境からはアンインストールされない
  # （新規環境に入らなくなるだけ）
  home.activation.installEditorExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /bin/bash ${dotfilesPath}/vscode/install-extensions.sh
  '';

  # ~/.claude 配下のリンクは既存の setup.sh に委譲する。
  # setup.sh は「リンクが実体ファイルで上書きされた場合に実体側を
  # リポジトリへ取り込んでからリンクし直す」セルフヒーリングを持ち、
  # home-managerの宣言管理では再現できないため、あえて移行しない
  home.activation.linkClaudeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /bin/bash ${dotfilesPath}/.claude/setup.sh
  '';
}
