{ config, pkgs, lib, ... }:

let

  inherit (builtins) elem isBool isString;
  inherit (lib)
    concatMapStringsSep concatStringsSep filterAttrs imap
    mapAttrsToList mkIf mkOption optionalString ;
  inherit (lib.types)
    attrsOf bool either enum int listOf nullOr path str submodule ;

  default = v: type: mkOption { type = type; default = v; };
  explicit = filterAttrs (n: v: n != "_module" && v != null);
  mandatory = t: mkOption { type = t; };
  optional = t: mkOption { type = nullOr t; default = null; };

  secret = either str (
    submodule { options = { file = mandatory path; }; }
  );

  concatMapAttrsSep = s: f: attrs: concatStringsSep s (mapAttrsToList f attrs);

  cfg = config.nixsap.apps.sproxy2;

  show = v:
         if v ? file then "!include '${v.file}'"
    else if isString v then "'${v}'"
    else if isBool v then (if v then "true" else "false")
    else toString v;

  top = concatMapAttrsSep "\n" (k: v: "${k}: ${show v}")
    (filterAttrs (n: _:
      ! elem n [
        "backends"
        "enable"
        "oauth2"
        "ssl_cert_chain"
      ]
    ) (explicit cfg));

  configFile = with cfg; pkgs.writeText "sproxy.yml" ''
    ---
    ${top}

    ${optionalString (ssl_cert_chain != [])
    ''ssl_cert_chain:
    ${concatMapStringsSep "\n" (f: "  - ${show f}") ssl_cert_chain}''}


    oauth2:
    ${concatMapAttrsSep "\n\n" (p: {client_id, client_secret, ...}: ''
      ${"  ${p}"}:
          client_id: ${show client_id}
          client_secret: ${show client_secret}''
    ) cfg.oauth2}


    backends:
    ${concatMapStringsSep "\n\n" (b:
      let lines = mapAttrsToList (k: v: "${k}: ${show v}") (explicit b);
          be = imap (i: l: "  " + (if i == 1 then "- ${l}" else "  ${l}")) lines;
      in concatStringsSep "\n" be
    ) cfg.backends}

    ...
  '';

  maybeKey = a: if a ? file then a.file else null;
  keys = [ cfg.ssl_key cfg.pgpassfile ( maybeKey cfg.key ) ]
       ++ mapAttrsToList (_: c: maybeKey c.client_secret) (explicit cfg.oauth2)
       ;

  oauth2 = mkOption {
    description = ''
      OAuth2 providers. At least one is required.
      Refer to Sproxy2 for supported providers.
    '';
    type = attrsOf (submodule {
      options = {
        client_id = mandatory str;
        client_secret = mandatory secret;
      };
    });
  };

  backends = mkOption {
    description = ''
      Backends. At least one is required.
      Refer to Sproxy2 for description.
    '';
    type = listOf (submodule {
      options = {
        address        = optional str;
        conn_count     = optional int;
        cookie_domain  = optional str;
        cookie_max_age = optional int;
        cookie_name    = optional str;
        name           = optional str;
        port           = optional int;
        socket         = optional path;
      };
    });
    default = [];
  };

in {
  options.nixsap.apps.sproxy2 = {
    enable = mkOption {
      description = "Enable Sproxy2";
      type = bool;
      default = (cfg.backends != []);
    };

    inherit oauth2 backends;
    user = mkOption {
      description = "User to run as";
      type = str;
      default = "sproxy2";
    };
    home = mkOption {
      description = "Sproxy2 home directory for internal data";
      type = path;
      default = "/sproxy2";
    };
    listen = mkOption {
      description = "TCP port to listen on";
      type = int;
      default = 443;
    };
    listen80 = mkOption {
      description = "Whether to listen on port 80 (and redirect to HTTPS)";
      type = bool;
      default = true;
    };
    http2 = mkOption {
      description = "Whether HTTP/2 is enabled";
      type = nullOr bool;
      default = null;
    };
    ssl = mkOption {
      description = "Whether SSL is enabled.";
      type = nullOr bool;
      default = null;
    };
    https_port = mkOption {
      description = "Port used in redirect to HTTPS";
      type = nullOr int;
      default = null;
    };
    log_level = mkOption {
      description = "Log level";
      type = enum [ "error" "warn" "info" "debug" ];
      default = "info";
    };
    key = mkOption {
      description = "A key used to sign cookies and state (secret)";
      type = nullOr secret;
      default = null;
    };
    database = mkOption {
      description = "PostgreSQL connection string";
      type = nullOr str;
      default = null;
      example = "host=db.example.net user=sproxy dbname=sproxy port=6000";
    };
    pgpassfile = mkOption {
      description = "PostgreSQL password file (secret)";
      type = nullOr path;
      default = null;
    };
    datafile = mkOption {
      description = "Read permissions from this file";
      type = nullOr path;
      default = null;
    };
    ssl_key = mkOption {
      description = "SSL key (PEM format) - secret";
      type = nullOr path;
      default = null;
    };
    ssl_cert = mkOption {
      description = "SSL certificate (PEM format)";
      type = nullOr path;
      default = null;
    };
    ssl_cert_chain = mkOption {
      description = "SSL certificate chain";
      type = listOf path;
      default = [];
    };
  };

  config = mkIf cfg.enable {
    nixsap.system.users.daemons = [ cfg.user ];
    nixsap.deployment.keyrings.${cfg.user} = keys;
    systemd.services.sproxy2 = {
      description = "Sproxy2 secure HTTP proxy";
      wantedBy = [ "multi-user.target" ];
      wants = [ "keys.target" ];
      after = [ "keys.target" "network.target" "local-fs.target" ];
      preStart = ''
        mkdir -p -- '${cfg.home}'
        chown -Rc '${cfg.user}:${cfg.user}' -- '${cfg.home}'
        chmod -Rc u=rwX,g=rX,o= -- '${cfg.home}'
      '';
      serviceConfig = {
        ExecStart = "${pkgs.sproxy2}/bin/sproxy2 --config=${configFile}";
        Restart = "always";
      };
    };
  };
}

