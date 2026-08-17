{
  description = "peipou's Ubuntu environment (home-manager standalone)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      # このマシンのユーザー名。新しいマシンでは bootstrap.sh が
      # 実際のユーザー名に自動で書き換える（手動で編集してもよい）
      username = "peipou";
      # このリポジトリの実体パス。
      # .claude/ や zsh/ への「書き込み可能なリンク」を張るために使う。
      # クローン先は bootstrap.sh が ~/Dev/kaishi/ubuntu-dotfiles に統一する
      dotfilesPath = "/home/${username}/Dev/kaishi/ubuntu-dotfiles";
      # CPUアーキテクチャ。ARM環境（Raspberry Pi等）では "aarch64-linux" に変更する
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      # マシン（ホスト名）に依存しない固定の構成名。
      # 適用時は `--flake <リポジトリ>#ubuntu` と明示的に指定する
      homeConfigurations."ubuntu" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit username dotfilesPath; };
        modules = [
          ./nix/home.nix
          ./nix/packages.nix
          ./nix/keyboard.nix
        ];
      };
    };
}
