{ pkgs, ... }:
{
  # CLIツールはすべてnixpkgsで管理する。
  # バージョンは flake.lock で固定され、新しいマシンでも同一バージョンが入る。
  # 更新したいときは `nix flake update` → `home-manager switch`
  home.packages = with pkgs; [
    # バージョン管理
    git
    gh

    # JavaScript / Node.js
    nodejs_26
    pnpm

    # コンテナ・インフラ
    docker # dockerクライアントCLI（Docker Engine本体はaptで導入する。nix/README.md参照）
    docker-compose
    supabase-cli
    # 注: Claude Code CLIは意図的にNix管理外。
    # 常に最新版を使うため、公式ネイティブインストーラー（自動更新あり）で
    # 導入する（bootstrap.sh が担当）

    # ユーティリティ
    jq

    # フォント。Powerlevel10kのアイコン・区切り記号の描画に必要なNerd Font。
    # Ubuntu標準ターミナルと同じ細い字幅を保つためUbuntuMonoのNerd Font版を使う
    # （fontconfigへの反映は home.nix の fonts.fontconfig.enable が担う）
    nerd-fonts.ubuntu-mono
  ];
}
