{ config, pkgs, lib, ... }:

let

  inherit (lib) mkIf mkOption mkEnableOption types filterAttrs
                mapAttrsToList concatStringsSep;
  inherit (types) int bool nullOr attrsOf str either enum submodule lines path;

  inherit (builtins) isBool filter toString;

  cfg = config.nixsap.apps.nginx;
  explicit = filterAttrs (n: v: n != "_module" && v != null);

  attrs = opts: submodule { options = opts; };
  default = d: t: mkOption { type = t; default = d; };
  optional = t: mkOption { type = nullOr t; default = null; };

  show = v: if isBool v then (if v then "on" else "off") else toString v;

  format = indent: set:
    let mkEntry = k: v: "${indent}${k} ${show v};";
    in concatStringsSep "\n" (mapAttrsToList mkEntry (explicit set));

  mkServer = name: text: ''
    server {
    ${text}
    }
  '';

  # Hardcode defaults that could be overriden in server context.
  # Add options for http-only directives.
  nginx-conf = pkgs.writeText "nginx.conf" ''
    daemon off;
    user ${cfg.user} ${cfg.user};
    pid ${cfg.runDir}/nginx.pid;

    ${format "" cfg.main}

    events {
    ${format "  " cfg.events}
    }

    http {
      include ${pkgs.nginx}/conf/mime.types;
      default_type application/octet-stream;

      access_log off;
      error_log stderr;

      gzip on;
      keepalive_timeout 65;
      sendfile on;
      ssl_prefer_server_ciphers on;
      ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
      tcp_nodelay on;
      tcp_nopush on;
      types_hash_max_size 2048;

      # https://www.nginx.com/blog/mitigating-the-httpoxy-vulnerability-with-nginx/
      fastcgi_param HTTP_PROXY "";
      proxy_set_header Proxy "";

      ${concatStringsSep "\n" (mapAttrsToList mkServer cfg.http.servers)}
    }
  '';

  exec = "${pkgs.nginx}/bin/nginx -c ${nginx-conf} -p ${cfg.stateDir}";

in {

  options.nixsap.apps.nginx = {
    user = mkOption {
      description = "User to run as";
      type = str;
      default = "nginx";
    };
    stateDir = mkOption {
      description = "Directory holding all state for nginx to run";
      type = path;
      default = "/nginx";
    };
    runDir = mkOption {
      description = ''
        Directory for sockets and PID-file.
        UNIX-sockets created by nginx are world-writable.
        So if you want some privacy, put sockets in this directory.
        It is owned by nginx user and group, and has mode 0640.
      '';
      type = path;
      readOnly = true;
      default = "/run/nginx";
    };

    main = default {} (attrs {
      pcre_jit = optional bool;
      timer_resolution = optional int;
      worker_cpu_affinity = optional str;
      worker_priority = optional int;
      worker_processes = default "auto" (either int (enum ["auto"]));
      worker_rlimit_core = optional int;
      worker_rlimit_nofile = optional int;
    });

    events = default {} (attrs {
      accept_mutex = optional bool;
      accept_mutex_delay = optional int;
      multi_accept = optional bool;
      worker_aio_requests = optional int;
      worker_connections = optional int;
    });

    http = default {} (attrs {
      servers = default {} (attrsOf lines);
    });
  };

  config = mkIf ({} != explicit cfg.http.servers) {
    nixsap.system.users.daemons = [ cfg.user ];
    systemd.services.nginx = {
      description = "web/proxy server";
      wants = [ "keys.target" ];
      after = [ "keys.target" "local-fs.target" "network.target" ];
      wantedBy = [ "multi-user.target" ];
      preStart = ''
        rm -rf '${cfg.runDir}'
        mkdir -p '${cfg.stateDir}/logs' '${cfg.runDir}'
        chown -Rc '${cfg.user}:${cfg.user}' '${cfg.stateDir}' '${cfg.runDir}'
        chmod -Rc u=rwX,g=rX,o= '${cfg.stateDir}' '${cfg.runDir}'
      '';
      serviceConfig = {
        ExecStart = exec;
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        RestartSec = "10s";
        StartLimitInterval = "1min";
        Restart = "always";
      };
    };
  };
}

