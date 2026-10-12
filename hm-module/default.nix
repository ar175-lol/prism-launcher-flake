{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.programs.prism-launcher;

  # `jdks` feeds qtWrapperArgs (--prefix PRISMLAUNCHER_JAVA_PATHS), so it is
  # a real argument to the package and changing it changes the derivation.
  prismPackage = cfg.package.override { inherit (cfg) jdks; };

  # Minecraft's offline-mode UUID is MD5("OfflinePlayer:<name>"), formatted as
  # a UUID. That only rewrites two of the digest's 32 hex characters: the
  # version nibble (character 12, forced to "3") and the variant nibble
  # (character 16, forced to 8-b), so we patch those characters in place
  # rather than unpacking the digest into bytes. Matches
  # MinecraftAccount::createOffline() upstream, which also sets
  # ygg.extra.userName = the username.
  hexChars = [
    "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f"
  ];
  hexVals = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };
  mod = a: b: a - (a / b) * b;
  mkOfflineId =
    name:
    let
      hash = builtins.hashString "md5" "OfflinePlayer:${name}";
      # variant = 0b10xx, i.e. the low two bits of the original nibble
      variant = i: builtins.elemAt hexChars (8 + mod (hexVals.${substring i 1 hash}) 4);
    in
    substring 0 8 hash
    + "-"
    + substring 8 4 hash
    + "-3"
    + substring 13 3 hash
    + "-"
    + variant 16
    + substring 17 3 hash
    + "-"
    + substring 20 12 hash;

  mkAccount =
    username:
    {
      accounts = [
        {
          active = true;
          entitlement = {
            canPlayMinecraft = true;
            ownsMinecraft = true;
          };
          profile = {
            capes = [ ];
            id = mkOfflineId username;
            name = username;
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
              userName = username;
            };
            iat = 0;
            token = "0";
          };
        }
      ];
      formatVersion = 3;
    };

  seedStorePath = pkgs.writeText "prism-accounts.json" (
    builtins.toJSON (mkAccount cfg.offline.username)
  );
in
{
  options.programs.prism-launcher = {
    enable = mkEnableOption "Prism Launcher";

    package = mkOption {
      type = types.package;
      default = pkgs.prismlauncher;
      defaultText = literalExpression "pkgs.prismlauncher";
      description = ''
        Prism Launcher package to install. Must accept a `jdks` argument,
        which stock nixpkgs' prismlauncher does.
      '';
    };

    jdks = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [ jdk21 ];
      defaultText = literalExpression "[ pkgs.jdk21 ]";
      description = ''
        Java runtimes exposed to the launcher via PRISMLAUNCHER_JAVA_PATHS.
        Note that changing this changes the package derivation and triggers
        a full rebuild of Prism Launcher, Java parts included.
      '';
    };

    offline = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Seed a ready-to-use offline account on first activation.

          Stock Prism gates its "Add Offline" action (and the launch-time
          account check) behind having an account that owns Minecraft, so
          there is no way to bootstrap an offline-only setup from the GUI.
          This writes accounts.json directly instead.

          The file is only written if it does not already exist — after the
          first run Prism owns it, and account management works normally.
          Delete ~/.local/share/PrismLauncher/accounts.json to re-seed.
        '';
      };

      username = mkOption {
        type = types.str;
        default = "Player";
        description = "Username for the generated offline account.";
      };
    };
  };

  config = mkIf cfg.enable {
    warnings = mkIf cfg.offline.enable [
      ''
        programs.prism-launcher.offline.enable seeds an account that plays
        without a Microsoft login. Using it against Mojang's servers is
        against their Terms of Service; singleplayer, LAN and offline-mode
        servers are unaffected.
      ''
    ];

    home.packages = [ prismPackage ];

    home.activation.prismSeedAccounts = mkIf cfg.offline.enable (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        data_home="''${XDG_DATA_HOME:-''${HOME}/.local/share}"
        accounts="''${data_home}/PrismLauncher/accounts.json"

        mkdir -p "''${data_home}/PrismLauncher"

        if [ -e "''${accounts}" ]; then
          echo "prism-launcher: accounts.json exists, leaving it untouched"
        else
          cp ${seedStorePath} "''${accounts}"
          chmod u+w "''${accounts}"
          echo "prism-launcher: seeded offline account '${cfg.offline.username}'"
        fi
      ''
    );
  };
}
