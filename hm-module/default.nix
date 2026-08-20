{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib; let
  cfg = config.programs.prism-launcher;

  basePackage =
    if cfg.offline.enable
    then self.packages.${pkgs.stdenv.hostPlatform.system}.stable
    else pkgs.prismlauncher;

  prismPackage = basePackage.override {
    inherit
      (cfg)
      jdks
      ;
  };
in {
  options.programs.prism-launcher = {
    enable = mkEnableOption "Prism Launcher";

    offline = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable offline mode. Forces 8.4 version.";
      };

      username = mkOption {
        type = types.str;
        default = "Player";
        description = "Nickname for the generated offline MSA account.";
      };
    };

    jdks = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [jdk21];
      description = "List of Java runtimes visible to the launcher.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [prismPackage];

    xdg.dataFile."PrismLauncher/accounts.json" = mkIf cfg.offline.enable {
      text = builtins.toJSON {
        accounts = [
          {
            active = true;
            entitlement = {
              canPlayMinecraft = true;
              ownsMinecraft = true;
            };
            profile = {
              capes = [];
              id = "00000000-0000-4000-8000-000000000000";
              name = cfg.offline.username;
              skin = {
                id = "";
                url = "";
                variant = "";
              };
            };
            type = "Offline";
            ygg = {
              extra = {
                clientToken = "0";
                userName = "";
              };
              iat = 0;
              token = "0";
            };
          }
        ];
        formatVersion = 3;
      };
    };
  };
}
