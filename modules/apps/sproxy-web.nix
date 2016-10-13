{ config, pkgs, lib, ... }:

let

  inherit (builtins) toString ;
  inherit (lib)
    concatStrings hasPrefix mkEnableOption mkIf mkOption
    optionalString types ;
  inherit (types)
    int nullOr path str ;

  cfg = config.nixsap.apps.sproxy-web;

  ExecStart = concatStrings [
    "${pkgs.sproxy-web}/bin/sproxy-web"
    (optionalString (cfg.connectionString != null) " -c '${cfg.connectionString}'")
    (if (cfg.port != null)
      then " -p ${toString cfg.port}"
      else " -s '${cfg.socket}'")
  ];

in {
  options.nixsap.apps.sproxy-web = {
    enable = mkEnableOption "Sproxy Web";
    user = mkOption {
      description = "User to run as";
      default = "sproxy-web";
      type = str;
    };
    connectionString = mkOption {
      description = "PostgreSQL connection string";
      type = str;
      example = "user=sproxy-web dbname=sproxy port=6001";
    };
    pgPassFile = mkOption {
      description = "postgreSQL password file (secret)";
      default = null;
      type = nullOr path;
    };
    socket = mkOption {
      description = "UNIX socket to listen on. Ignored when TCP port is set";
      default = "/tmp/sproxy-web.sock";
      type = path;
    };
    port = mkOption {
      description = "TCP port to listen on (insecure)";
      type = nullOr int;
      default = null;
    };
  };

  config = mkIf cfg.enable {
    nixsap.system.users.daemons = [ cfg.user ];
    nixsap.deployment.keyrings.${cfg.user} = [ cfg.pgPassFile ];
    systemd.services.sproxy-web = {
      description = "Web interface to Sproxy database";
      wantedBy = [ "multi-user.target" ];
      wants = [ "keys.target" ];
      after = [ "keys.target" "network.target" "local-fs.target" ];
      serviceConfig = {
        inherit ExecStart;
        Restart = "on-failure";
        User = cfg.user;
      };
      environment.PGPASSFILE = cfg.pgPassFile;
    };
  };
}

