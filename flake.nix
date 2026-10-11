{
  description = "Prism Launcher Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
  in
    (flake-utils.lib.eachSystem supportedSystems (
      system: let
        pkgs = import nixpkgs {inherit system;};
      in {
        packages.default = pkgs.prismlauncher;
      }
    ))
    // {
      homeModules.default = _: {
        imports = [./hm-module];
        _module.args = {inherit self;};
      };
    };
}
