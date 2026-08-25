{
  config,
  lib,
  pkgs,
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

  # Nixで導入したフォント（packages.nixのnerd-fonts）をfontconfigに認識させる
  fonts.fontconfig.enable = true;

  # GNOME端末の見た目。フォントはNerd Font（Powerlevel10kのアイコン描画に必要）、
  # 配色はmacOSターミナル「Pro」風の黒背景・白文字。ANSIカラーはApple純正だと
  # 黒背景で青・黄が沈んで読めないため、黒背景用に設計された
  # VS Code Dark+ 系の視認性の高いパレットを使う。
  # UUIDはUbuntuが標準で配布する既定プロファイルのもので、マシン間で共通。
  # GUIでプロファイルを作り直した場合はUUIDが変わるのでこの設定は効かなくなる
  dconf.settings."org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
    use-system-font = false;
    font = "UbuntuMono Nerd Font Mono 13";
    use-theme-colors = false;
    background-color = "#000000";
    foreground-color = "#F2F2F2";
    palette = [
      "#000000" # black
      "#CD3131" # red
      "#0DBC79" # green
      "#E5E510" # yellow
      "#2472C8" # blue
      "#BC3FBC" # magenta
      "#11A8CD" # cyan
      "#E5E5E5" # white
      "#666666" # bright black
      "#F14C4C" # bright red
      "#23D18B" # bright green
      "#F5F543" # bright yellow
      "#3B8EEA" # bright blue
      "#D670D6" # bright magenta
      "#29B8DB" # bright cyan
      "#FFFFFF" # bright white
    ];
  };

  # ~/.zshrc はリポジトリ実体への「書き込み可能なリンク」にする。
  # home-manager標準のstore管理だと読み取り専用になり、
  # リポジトリ側を直接編集して即反映という現在の運用ができなくなるため
  home.file = {
    ".zshrc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/zsh/.zshrc";
    # bashが対話起動されたらzshへ引き継ぐ（bashは使わない運用）。
    # force = true はUbuntu標準の実体 ~/.bashrc をリンクへ置き換えるために必要
    ".bashrc" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/zsh/.bashrc";
      force = true;
    };
    # Powerlevel10kの設定（macOS風の最小構成）。
    # force = true は `p10k configure` が実体ファイルを生成してリンクを
    # 上書きしてしまった場合に、次回switchでリンクへ戻すため
    ".p10k.zsh" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/zsh/.p10k.zsh";
      force = true;
    };
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

  # direnv: .envrc のあるプロジェクトディレクトリに cd した瞬間、
  # そのプロジェクトの flake.nix devShell を自動で有効化/無効化する。
  # nix-direnv は devShell の評価結果をキャッシュして即座に切り替えるための拡張
  # （direnvrc の配線も home-manager が自動生成する）。
  # zsh へのフックは ~/.zshrc が mkOutOfStoreSymlink 管理（home-manager 非管理）のため
  # enableZshIntegration では注入されず、zsh/.zshrc に直接記述している
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # iPhoneプッシュ通知の送信スクリプト（claude-notify/send-push.mjs）は
  # web-push に依存するため、node_modules を activation 時に用意する。
  # node_modules はリポジトリ管理外（.gitignore）なので、新しいUbuntuマシンでも
  # `home-manager switch` だけで送信できる状態になる。
  # pnpm は実行に node を要するので PATH に nodejs を通す。
  # オフライン等でインストールに失敗しても switch 全体は失敗させない
  home.activation.installClaudeNotifyDeps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bash}/bin/bash -c '
      export PATH="${pkgs.nodejs_26}/bin:$PATH"
      cd "${dotfilesPath}/claude-notify" &&
        "${pkgs.pnpm}/bin/pnpm" install --frozen-lockfile
    ' || echo "警告: claude-notify の依存インストールに失敗しました（iPhone通知は無効のまま。ネットワーク接続後に手動で 'cd ${dotfilesPath}/claude-notify && pnpm install' を実行してください）"
  '';
}
