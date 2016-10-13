{ config, pkgs, lib, ... }:

let
  inherit (builtins) toString;
  inherit (lib) types mkOption mkEnableOption mkIf hasPrefix
                concatStrings optionalString;
  inherit (types) str path int nullOr;

  cfg = config.nixsap.apps.juandelacosa;

  ExecStart = concatStrings [
    "${pkgs.juandelacosa}/bin/juandelacosa"
    (optionalString (cfg.myFile != null) " -f '${cfg.myFile}'")
    (optionalString (cfg.myGroup != null) " -g ${cfg.myGroup}")
    (if (cfg.port != null)
      then " -p ${toString cfg.port}"
      else " -s '${cfg.socket}'")
  ];

in {
  options.nixsap.apps.juandelacosa = {
    enable = mkEnableOption "Juan de la Cosa";
    user = mkOption {
      description = "User to run as";
      default = "juandelacosa";
      type = str;
    };
    port = mkOption {
      description = "TCP port to listen on";
      default = null;
      type = nullOr int;
    };
    socket = mkOption {
      description = "UNIX socket to listen on. Ignored when TCP port is set";
      default = "/tmp/juandelacosa.sock";
      type = path;
    };
    myFile = mkOption {
      description = "MySQL client configuration file";
      default = null;
      type = nullOr path;
    };
    myGroup = mkOption {
      description = "Options group in the MySQL client configuration file";
      default = null;
      type = nullOr str;
    };
  };

  config = mkIf cfg.enable {
    nixsap.system.users.daemons = [ cfg.user ];
    nixsap.deployment.keyrings.${cfg.user} = [ cfg.myFile ];
    systemd.services.juandelacosa = {
      description = "captain of the MariaDB";
      wantedBy = [ "multi-user.target" ];
      wants = [ "keys.target" ];
      after = [ "keys.target" "network.target" "local-fs.target" ];
      serviceConfig = {
        inherit ExecStart;
        User = cfg.user;
        Restart = "on-failure";
      };
    };
  };
}

