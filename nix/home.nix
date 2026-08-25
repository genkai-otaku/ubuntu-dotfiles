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
    font = "UbuntuMono Nerd Font Mono 10";
    use-theme-colors = false;
    background-color = "#000000";
    foreground-color = "#F2F2F2";
    # Ubuntu既定の 80x24 より広いサイズ
    default-size-columns = 120;
    default-size-rows = 30;
    bold-color-same-as-fg = true;
    bold-is-bright = true;
    audible-bell = false;
    # 黒背景のまま 20% 透過。use-theme-transparency を切らないと
    # テーマ側の透過設定に上書きされる
    use-theme-transparency = false;
    use-transparent-background = true;
    background-transparency-percent = 20;
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
    # git設定。force = true は既存の実体ファイル ~/.gitconfig をリンクへ
    # 置き換えるために必要。user.name / user.email はリポジトリに含めず、
    # 各PCで手動配置する ~/.gitconfig.local（git管理外）から include される
    ".gitconfig" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/git/.gitconfig";
      force = true;
    };
    # Grok CLI の設定。grok 自身もこのファイルへ書き込むため、書き込み可能
    # リンクにして変更をリポジトリ側へ取り込む（VSCode設定と同じ方式）。
    # force = true は既存実体ファイルの置き換え用
    ".grok/config.toml" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/grok/config.toml";
      force = true;
    };
    # Grok CLI のグローバル指示ファイル（Grok固有の補足のみ。共通ルールは
    # Claude互換モードで ~/.claude/CLAUDE.md から読み込まれるため重複させない）
    ".grok/AGENTS.md" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/grok/AGENTS.md";
      force = true;
    };
    # VSCode 起動ラッパー。snap の electron-launch が GDK_BACKEND=wayland と
    # --ozone-platform=x11 を同時に立て、IME が二重になって TUI へ変換中プレビュー
    # が漏れるのを、DISABLE_WAYLAND=1 + GDK_BACKEND=x11 + GTK_IM_MODULE=xim で一本化する。
    # ~/.local/bin は PATH 上 /snap/bin より前。本体はラッパーが /snap/bin/code を exec する
    ".local/bin/code" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/vscode/code";
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

  # 既定ブラウザを Google Chrome にする（Dock先頭・bootstrap導入と揃える）。
  # xdg-open や GNOME のリンク開きが Firefox（Ubuntu既定snap）に流れないようにする。
  # force = true は Ubuntu が既に作っている実体をリンクへ置き換えるために必要。
  # mimeApps は ~/.config と ~/.local/share/applications の両方に書く
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
    };
  };
  xdg.configFile."mimeapps.list".force = true;
  xdg.dataFile."applications/mimeapps.list".force = true;

  # ドック／アプリ一覧からの起動は PATH を見ないため、snap の desktop を
  # ユーザー側で上書きしてラッパー経由にする。ID は snap と同じ code_code.desktop
  xdg.dataFile."applications/code_code.desktop".text = ''
    [Desktop Entry]
    X-SnapInstanceName=code
    Name=Visual Studio Code
    Comment=Code Editing. Redefined.
    GenericName=Text Editor
    X-SnapAppName=code
    X-SnapCommonID=code.desktop
    Exec=${config.home.homeDirectory}/.local/bin/code --force-user-env %F
    Icon=/snap/code/current/meta/gui/vscode.png
    Type=Application
    StartupNotify=false
    StartupWMClass=Code
    Categories=TextEditor;Development;IDE;
    MimeType=application/x-code-workspace;
    Actions=new-empty-window;
    Keywords=vscode;

    [Desktop Action new-empty-window]
    Name=New Empty Window
    Name[ja]=新しい空のウィンドウ
    X-SnapAppName=code
    X-SnapCommonID=code.desktop
    Exec=${config.home.homeDirectory}/.local/bin/code --force-user-env --new-window %F
    Icon=/snap/code/current/meta/gui/vscode.png
  '';
  xdg.dataFile."applications/code_code-url-handler.desktop".text = ''
    [Desktop Entry]
    X-SnapInstanceName=code
    Name=Visual Studio Code - URL Handler
    Comment=Code Editing. Redefined.
    GenericName=Text Editor
    X-SnapAppName=code
    X-SnapCommonID=code.desktop
    Exec=${config.home.homeDirectory}/.local/bin/code --force-user-env --open-url %U
    Icon=/snap/code/current/meta/gui/vscode.png
    Type=Application
    NoDisplay=true
    StartupNotify=true
    Categories=Utility;TextEditor;Development;IDE;
    MimeType=x-scheme-handler/vscode;
    Keywords=vscode;
  '';

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

  # gh は ~/.config/gh/config.yml を自分で書き換えるツールなのでファイルリンクでは
  # 管理せず、activation で `gh alias set` を実行して co: pr checkout のエイリアスを
  # 冪等に設定する。--clobber は既存エイリアスがあっても上書きして冪等にするため。
  # gh未導入やネットワーク不通でも switch を止めない
  home.activation.setGhAlias = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.gh}/bin/gh alias set co "pr checkout" --clobber \
      || echo "警告: gh のエイリアス設定に失敗しました（gh未導入またはネットワーク不通の可能性）"
  '';
}
