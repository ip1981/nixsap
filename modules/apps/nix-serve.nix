{ config, pkgs, lib, ... }:

let

  inherit (lib)
    mkEnableOption mkIf mkOption optionalString ;

  inherit (lib.types)
    int nullOr package path str ;

  cfg = config.nixsap.apps.nix-serve;

  start =
    let
      maybeTCP = optionalString (cfg.port != null)
                   "--listen '${cfg.address}:${toString cfg.port}'";
    in pkgs.writeBashScriptBin "nix-serve" ''
      umask 0117 # for socket mode

      export NIX_REMOTE="daemon"

      ${optionalString (cfg.secretKeyFile != null) ''
        export NIX_SECRET_KEY_FILE='${cfg.secretKeyFile}'
      ''}

      exec "${cfg.package}/bin/nix-serve" \
        ${maybeTCP} \
        --listen '${cfg.socket}' \
        --workers ${toString cfg.workers}
    '';

in
{
  options = {
    nixsap.apps.nix-serve = {
      enable = mkEnableOption "nix-serve, the standalone Nix binary cache server";

      user = mkOption {
        description = "User and group to run as";
        type = str;
        default = "nix-serve";
      };

      home = mkOption {
        description = "Home directory (currently for Unix socket only)";
        type = path;
        default = "/nix-serve";
      };

      package = mkOption {
        description = "nix-serve package";
        type = package;
        default = pkgs.nix-serve;
      };

      workers = mkOption {
        type = int;
        default = 5;
        description = "Specifies the number of worker pool";
      };

      port = mkOption {
        type = nullOr int;
        default = null;
        description = ''
          Port number where nix-serve will listen on in addition to Unix
          socket.  By default nix-serve listens on Unix socket only.
        '';
      };

      address = mkOption {
        type = str;
        default = "127.0.0.1";
        description = ''
          IP address where nix-serve will bind its TCP listening socket.
        '';
      };

      socket = mkOption {
        description = ''
          Unix socket to listen on.
        '';
        readOnly = true;
        type = path;
        default = "${cfg.home}/socket";
      };

      secretKeyFile = mkOption {
        type = nullOr path;
        default = null;
        description = ''
          The path to the file used for signing derivation data.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    nix.allowedUsers = [ cfg.user ];

    nixsap.deployment.keyrings.${cfg.user} = [ cfg.secretKeyFile ];
    nixsap.system.users.daemons = [ cfg.user ];

    systemd.services.nix-serve = {
      description = "nix-serve binary cache server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "keys.target" ];
      after = [ "keys.target" "network.target" "local-fs.target" ];

      preStart = ''
        mkdir -p -- '${cfg.home}'
        rm -rf -- '${cfg.socket}'
        chown -Rc '${cfg.user}:${cfg.user}' -- '${cfg.home}'
        chmod -Rc u=rwX,g=rX,o= -- '${cfg.home}'
      '';

      serviceConfig = {
        ExecStart = "${start}/bin/nix-serve";
        KillMode = "mixed";
        PermissionsStartOnly = true;
        Restart = "always";
        User = cfg.user;
      };
    };
  };
}
