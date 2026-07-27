{
  description = "Prism Launcher Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    flake-utils,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
  in
    (flake-utils.lib.eachSystem supportedSystems (
      system: let
        pkgs = import nixpkgs {inherit system;};
        pkgs-stable = import nixpkgs-stable {inherit system;};
      in {
        packages.default = pkgs.prismlauncher;
        packages.stable = pkgs-stable.prismlauncher;
      }
    ))
    // {
      homeModules.default = _: {
        imports = [./hm-module];
        _module.args = {inherit self;};
      };
    };
}
