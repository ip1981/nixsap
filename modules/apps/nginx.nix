{ config, pkgs, lib, ... }:

let

  inherit (builtins)
    elem filter isBool ;

  inherit (lib)
    concatMapStrings concatStringsSep filterAttrs mapAttrsToList mkDefault
    mkEnableOption mkIf mkOption ;

  inherit (lib.types)
    attrsOf bool either enum int lines nullOr path str submodule ;


  cfg = config.nixsap.apps.nginx;
  explicit = filterAttrs (n: v: n != "_module" && v != null);

  attrs = opts: submodule { options = opts; };
  default = d: t: mkOption { type = t; default = d; };
  optional = t: mkOption { type = nullOr t; default = null; };

  show = v: if isBool v then (if v then "on" else "off") else toString v;

  format = indent: set:
    let mkEntry = k: v: "${indent}${k} ${show v};";
    in concatStringsSep "\n" (mapAttrsToList mkEntry (explicit set));

  mkServer = name: text: pkgs.writeText "nginx-${name}.conf" ''
    # ${name}:
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

    ${format "" (filterAttrs (n: _: ! elem n ["events" "http"]) cfg.conf)}

    events {
    ${format "  " cfg.conf.events}
    }

    http {
    ${cfg.conf.http.context}

    ${concatMapStrings (s: "include ${s};\n") (mapAttrsToList mkServer cfg.conf.http.servers)}
    }
  '';

  exec = "${pkgs.nginx}/bin/nginx -c ${nginx-conf} -p ${cfg.stateDir}";

  enabled = {} != explicit cfg.conf.http.servers;

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
    logDir = mkOption {
      description = ''
        Nginx directory for logs. This is read-only. Use it in configuration
        files of nginx itself or logrotate.
      '';
      type = path;
      readOnly = true;
      default = "${cfg.stateDir}/logs";
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

    conf = default {} (attrs {
      pcre_jit = optional bool;
      timer_resolution = optional int;
      worker_cpu_affinity = optional str;
      worker_priority = optional int;
      worker_processes = default "auto" (either int (enum ["auto"]));
      worker_rlimit_core = optional int;
      worker_rlimit_nofile = optional int;

      events = default {} (attrs {
        accept_mutex = optional bool;
        accept_mutex_delay = optional int;
        multi_accept = optional bool;
        worker_aio_requests = optional int;
        worker_connections = optional int;
      });

      http = default {} (attrs {
        servers = default {} (attrsOf lines);
        context = mkOption {
          description = ''
            Default directives in the http context.  You normally don't
            need to change it, because most of directives can be overriden
            in server or location contexts.  This parameter has a reasonale
            default value which you should append in nixos modules, i. e. by
            adding geoip directives or maps. Use `lib.mkForce` to completely
            omit default directives.
          '';
          type = lines;
        };
      });
    });
  };

  config = {
    nixsap.apps.nginx.conf.http.context = ''
      include ${pkgs.nginx}/conf/mime.types;
      default_type application/octet-stream;

      access_log off;
      error_log stderr info;

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
    '';

    nixsap.system.users.daemons = mkIf enabled [ cfg.user ];

    nixsap.apps.logrotate.conf.nginx = mkIf enabled {
      files = "${cfg.logDir}/*.log";
      directives = {
        delaycompress = mkDefault true;
        missingok = mkDefault true;
        notifempty = mkDefault true;
        rotate = mkDefault 14;
        sharedscripts = true;
        daily = mkDefault true;
        create = mkDefault "0640 ${cfg.user} ${cfg.user}";
        postrotate = pkgs.writeBashScript "logrotate-nginx-postrotate" "systemctl kill -s SIGUSR1 nginx.service";
      };
    };

    systemd.services.nginx = mkIf enabled {
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

