{ config, pkgs, lib, ... }:

let

  inherit (builtins) toString;
  inherit (lib)
    filter filterAttrs hasPrefix mapAttrsToList
    mkEnableOption concatStrings mkIf mkOption types ;
  inherit (types)
    enum int nullOr attrsOf path str submodule ;

  explicit = filterAttrs (n: v: n != "_module" && v != null);
  
  cfg = config.nixsap.apps.sproxy;

  oauth2Options = concatStrings (mapAttrsToList (n: c:
    if n == "google" then ''
      client_id : ${c.client_id}
      client_secret : ${c.client_secret_file}
    '' else ''
      ${n}_client_id : ${c.client_id}
      ${n}_client_secret : ${c.client_secret_file}
    ''
  ) (explicit cfg.oauth2));

  configFile = pkgs.writeText "sproxy.conf" ''
    ${oauth2Options}
    user               : ${cfg.user}
    cookie_domain      : ${cfg.cookieDomain}
    cookie_name        : ${cfg.cookieName}
    database           : "${cfg.database}"
    listen             : 443
    log_level          : ${cfg.logLevel}
    log_target         : stderr
    ssl_certs          : ${cfg.sslCert}
    ssl_key            : ${cfg.sslKey}
    session_shelf_life : ${toString cfg.sessionShelfLife}
    ${if cfg.backendSocket != null then ''
      backend_socket     : ${cfg.backendSocket}
    '' else ''
      backend_address    : ${cfg.backendAddress}
      backend_port       : ${toString cfg.backendPort}
    ''}
  '';

  keys = filter (hasPrefix "/run/keys/")
       ( [ cfg.sslKey ]
       ++ mapAttrsToList (_: c: c.client_secret_file) (explicit cfg.oauth2)
       );

  oauth2 = mkOption {
    type = attrsOf (submodule {
      options = {
        client_id = mkOption {
          type = str;
          description = "OAuth2 client id";
        };
        client_secret_file = mkOption {
          type = path;
          description = "File with OAuth2 client secret";
        };
      };
    });
    example = {
      google.client_id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com";
      google.client_secret_file = "/run/keys/google_oauth2_secret";
    };
  };

in {
  options.nixsap.apps.sproxy = {
    enable = mkEnableOption "SProxy";
    inherit oauth2;
    user = mkOption {
      description = "User to run as";
      default = "sproxy";
      type = str;
    };
    cookieDomain = mkOption {
      description = "Cookie domain";
      type = str;
      example = "example.com";
    };
    cookieName = mkOption {
      description = "Cookie name";
      type = str;
      example = "sproxy";
    };
    logLevel = mkOption {
      description = "Log level";
      default = "info";
      type = enum [ "info" "warn" "debug" ];
    };
    sslCert = mkOption {
      description = "SSL certificate (in PEM format)";
      type = path;
    };
    sslKey = mkOption {
      description = "SSL key (in PEM format) - secret";
      type = path;
    };
    backendAddress = mkOption {
      description = "Backend TCP address";
      type = str;
      default = "127.0.0.1";
    };
    backendPort = mkOption {
      description = "Backend TCP port";
      type = int;
      example = 8080;
    };
    backendSocket = mkOption {
      description = "Backend UNIX socket. If set, other backend options are ignored";
      type = nullOr path;
      default = null;
    };
    database = mkOption {
      description = "PostgreSQL connection string";
      type = str;
      example = "user=sproxy dbname=sproxy port=6001";
    };
    sessionShelfLife = mkOption {
      description = "Session shelf life in seconds";
      type = int;
      default = 3600 * 24 * 14; # two weeks
    };
  };

  config = mkIf cfg.enable {
    nixsap.system.users.daemons = [ cfg.user ];
    nixsap.deployment.keyrings.${cfg.user} = keys;
    systemd.services.sproxy = {
      description = "Sproxy secure proxy";
      wantedBy = [ "multi-user.target" ];
      wants = [ "keys.target" ];
      after = [ "keys.target" "network.target" "local-fs.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.sproxy}/bin/sproxy --config=${configFile}";
        Restart = "on-failure";
      };
    };
  };
}

