{ config, pkgs, lib, ... }:

let
  inherit (builtins) filter toString;
  inherit (lib) types mkOption mkEnableOption mkIf hasPrefix
                concatStrings optionalString;
  inherit (types) str path int nullOr;

  cfg = config.nixsap.apps.mywatch;

  ExecStart = concatStrings [
    "${pkgs.mywatch}/bin/mywatch"
    (if (cfg.port != null)
      then " -p ${toString cfg.port}"
      else " -s '${cfg.socket}'")
    " '${cfg.myFile}'"
  ];

  keys = filter (f: f != null && hasPrefix "/run/keys/" f) [ cfg.myFile ];

in {
  options.nixsap.apps.mywatch = {
    enable = mkEnableOption "MyWatch";
    user = mkOption {
      description = "User to run as";
      default = "mywatch";
      type = str;
    };
    port = mkOption {
      description = "TCP port to listen on (insecure)";
      default = null;
      type = nullOr int;
    };
    socket = mkOption {
      description = "UNIX socket to listen on. Ignored when TCP port is set";
      default = "/tmp/mywatch.sock";
      type = path;
    };
    myFile = mkOption {
      description = "MySQL client configuration file";
      type = path;
    };
  };

  config = mkIf cfg.enable {
    nixsap.system.users.daemons = [ cfg.user ];
    nixsap.deployment.keyrings.${cfg.user} = keys;
    systemd.services.mywatch = {
      description = "watch queries on multiple MySQL servers";
      wantedBy = [ "multi-user.target" ];
      wants = [ "keys.target" ];
      after = [ "keys.target" "network.target" ];
      serviceConfig = {
        inherit ExecStart;
        User = cfg.user;
        Restart = "on-failure";
      };
    };
  };
}

