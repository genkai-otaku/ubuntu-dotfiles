{ lib, ... }:
{
  # GNOMEのキーボード設定をdconfで宣言管理する。
  # 「Windowsの初期状態と同じ」挙動にする：
  #   - JIS配列（日本語キーボード）
  #   - 半角/全角キーでIME切り替え（ibus-mozcのデフォルト挙動。
  #     MozcのキーマップはMS-IME準拠が初期値のため追加設定は不要）
  #   - CapsLock/Ctrl入れ替えなどのキー入れ替えはしない
  # 注: ibus-mozc本体はNix管理外（apt install ibus-mozc で導入する）。
  # GNOMEとのIME統合はシステム側にある方がトラブルが少ないため
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      # 先頭が既定の入力ソース。mozc-jpを既定にし、
      # ibus-mozc未導入の環境でもJIS配列が使えるようxkbのjpも残す
      sources = [
        (lib.hm.gvariant.mkTuple [ "ibus" "mozc-jp" ])
        (lib.hm.gvariant.mkTuple [ "xkb" "jp" ])
      ];
      # 空リストを明示的に宣言することで、GUIから設定された
      # キー入れ替え（ctrl:nocaps等）も次回switch時に打ち消される
      xkb-options = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
    };
  };
}
