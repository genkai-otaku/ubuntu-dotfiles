{ lib, ... }:
{
  # GNOMEデスクトップの見た目・電源管理・キーバインドをdconfで宣言管理する。
  dconf.settings = {
    # 見た目（ダークテーマ・Yaruパープル系・カーソル）
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Yaru-purple-dark";
      icon-theme = "Yaru-purple";
      cursor-size = 32;
      cursor-blink-time = 1400;
    };

    # ウィンドウボタンをmacOSと同じ左上配置にする（閉じる・最小化・最大化）。
    # コロンより左がタイトルバー左側、右が右側。Ubuntu既定は
    # ':minimize,maximize,close'（全部右上）。
    # VSCode / Cursor は独自タイトルバーのためこの値を無視する。
    # 左上かつ一段にする設定は vscode/settings.json（詳細は vscode/README.md）
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "close,minimize,maximize:";
    };

    # ここから3セクション：画面ロック・自動スリープを意図的に無効化している
    # （開発機での利便性優先の設定）
    "org/gnome/desktop/session" = {
      idle-delay = lib.hm.gvariant.mkUint32 0;
    };

    "org/gnome/desktop/screensaver" = {
      lock-delay = lib.hm.gvariant.mkUint32 0;
      lock-enabled = false;
    };

    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-timeout = 3600;
      sleep-inactive-ac-type = "nothing";
    };

    # 夜間モードは常時オン。schedule-from と schedule-to を同じ 20:00 に
    # すると GNOME は 24 時間点灯とみなす（自動スケジュールは使わない）。
    # 色温度 4700K はスキーマ既定の 2700K より色味が弱い。GUI から変えた
    # 値は次回 switch でここに戻る
    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-schedule-automatic = false;
      night-light-schedule-from = 20.0;
      night-light-schedule-to = 20.0;
      night-light-temperature = lib.hm.gvariant.mkUint32 4700;
    };

    # マウス。speed の範囲は -1.0〜1.0。以前の -0.51 は libinput が
    # 全体を減速し、画面横断に大きな腕の移動が要った。
    # macOS 標準に近づける：adaptive（遅い動きは精密、速いフリックは
    # 加速して画面を跨ぐ。macOS の Pointer acceleration と同じ思想）。
    # speed は -0.3。0 より下げて通常速度もフリック最高速も少し遅くする。
    # -0.51 までは戻さない。
    # flat にすると加速がなくなり、また大きな移動が必要になる
    "org/gnome/desktop/peripherals/mouse" = {
      natural-scroll = false;
      accel-profile = "adaptive";
      speed = -0.3;
    };

    # タッチパッドは二本指スクロールを使う
    "org/gnome/desktop/peripherals/touchpad" = {
      two-finger-scrolling-enabled = true;
    };

    # ここから3セクション：tiling-assistant拡張を使うため、GNOME標準の
    # ウィンドウタイリング機能（キーバインド・エッジタイリング）を無効化して競合を避ける
    "org/gnome/desktop/wm/keybindings" = {
      activate-window-menu = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      maximize = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      unmaximize = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      switch-input-source = [ "<Shift><Alt>space" ];
      switch-input-source-backward = [ "<Alt>space" ];
    };

    "org/gnome/mutter" = {
      edge-tiling = false;
    };

    "org/gnome/mutter/keybindings" = {
      toggle-tiled-left = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      toggle-tiled-right = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      terminal = [ "<Primary>t" ];
    };

    # GNOME Terminalのキーバインド・挙動などUUID非依存の一般設定はここに置く。
    # home.nixの org/gnome/terminal/legacy/profiles:/:UUID はフォント・配色専用で
    # 機種依存のUUIDを含むため、あえてhome.nix側に残している
    "org/gnome/terminal/legacy" = {
      new-terminal-mode = "window";
    };

    # コピー/ペーストは他アプリと同じ Ctrl+C / Ctrl+V に揃える。
    # Copy を Ctrl+C にすると、GNOME Terminal は選択の有無にかかわらず
    # そのショートカットを常に消費する（未選択時も SIGINT を送らない）。
    # 割り込みは Ctrl+Shift+C が端末へ渡り、VTE が ^C（0x03）を出す想定。
    # VSCode 側は keybindings.json で Ctrl+Shift+C → SIGINT を明示している。
    "org/gnome/terminal/legacy/keybindings" = {
      copy = "<Primary>c";
      new-tab = "<Primary><Shift>t";
      paste = "<Primary>v";
      preferences = "<Primary>m";
      reset = "<Primary>backslash";
      reset-and-clear = "<Primary>asciicircum";
    };

    # Dashに常駐させるアプリ
    "org/gnome/shell" = {
      favorite-apps = [
        "google-chrome.desktop"
        "code_code.desktop"
        "slack_slack.desktop"
        "org.gnome.Terminal.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.Settings.desktop"
      ];
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      dash-max-icon-size = 48;
      dock-fixed = false;
      dock-position = "BOTTOM";
      extend-height = false;
      multi-monitor = true;
      show-trash = false;
    };

    "org/gnome/shell/extensions/ding" = {
      icon-size = "small";
      show-home = false;
      show-trash = false;
      start-corner = "top-left";
    };

    "org/gnome/shell/extensions/tiling-assistant" = {
      active-window-hint-color = "rgb(119,100,216)";
    };

    "org/gnome/system/location" = {
      enabled = true;
    };

    "org/gnome/desktop/privacy" = {
      recent-files-max-age = -1;
    };

    # ロックは無効化している（上記 screensaver）が、有効化したときも
    # ロック画面に通知を出さない
    "org/gnome/desktop/notifications" = {
      show-in-lock-screen = false;
    };

    "org/gnome/desktop/notifications/application/org-gnome-evolution-alarm-notify" = {
      enable = false;
    };

    "org/gnome/desktop/notifications/application/rhythmbox" = {
      enable = false;
    };

    "org/gnome/gedit/preferences/editor" = {
      scheme = "Yaru-dark";
    };
  };
}
