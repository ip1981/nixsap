{ config, pkgs, lib, ... }:

let

  inherit (builtins)
    filter isAttrs isBool ;

  inherit (lib)
    concatStringsSep filterAttrs hasPrefix mapAttrs' mapAttrsToList
    mkDefault mkIf mkOption ;

  inherit (lib.types)
    attrsOf bool either enum int nullOr package path str submodule ;


  explicit = filterAttrs (n: v: n != "_module" && v != null);
  concatNonEmpty = sep: list: concatStringsSep sep (filter (s: s != "") list);

  default = d: t: mkOption { type = t; default = d; };
  readonly = d: t: mkOption { type = t; default = d; readOnly = true; };
  mandatory = t: mkOption { type = t; };
  optional = t: mkOption { type = nullOr t; default = null; };

  instances = explicit (config.nixsap.apps.php-fpm);

  users = mapAttrsToList (_: v: v.user) instances;

  mkLogRotate = name: cfg:
    let instance = "php-fpm-${name}";
    in {
      name = instance;
      value = {
        files = "${cfg.logDir}/*.log";
        directives = {
          delaycompress = mkDefault true;
          missingok = mkDefault true;
          notifempty = mkDefault true;
          rotate = mkDefault 14;
          sharedscripts = true;
          daily = mkDefault true;
          create = mkDefault "0640 ${cfg.user} ${cfg.user}";
          postrotate = pkgs.writeBashScript "logrotate-${instance}-postrotate"
            "systemctl kill -s SIGUSR1 --kill-who=main '${instance}.service'";
        };
      };
    };

  mkService = name: cfg:
    let
      show = v: if isBool v then (if v then "yes" else "no") else toString v;

      mkGroup = group: opts: main:
        let f = k: v: if k == main
                      then "${group} = ${show v}"
                      else "${group}.${k} = ${show v}";
        in concatNonEmpty "\n" (mapAttrsToList f (explicit opts));

      mkEnv = t: k: v: "${t}[${k}] = ${show v}";

      mkPool = k: v:
        if k == "listen" then mkGroup k v "socket"
        else if k == "env" || hasPrefix "php_" k then concatNonEmpty "\n" (mapAttrsToList (mkEnv k) v)
        else if k == "pm" then mkGroup k v "strategy"
        else if isAttrs v then mkGroup k v ""
        else "${k} = ${show v}";

      mkGlobal = k: v:
        if isAttrs v then mkGroup k v ""
        else "${k} = ${show v}";

      conf = pkgs.writeText "php-fpm-${name}.conf" ''
        [global]
        daemonize = no
        ${concatNonEmpty "\n" (mapAttrsToList mkGlobal (explicit cfg.global))}

        [pool]
        listen.mode = 0660
        ${concatNonEmpty "\n" (mapAttrsToList mkPool (explicit cfg.pool))}
      '';
      exec = "${cfg.package}/bin/php-fpm --fpm-config ${conf} "
           + ( if cfg.php-ini != null
               then "--php-ini ${cfg.php-ini}"
               else "--no-php-ini" );
    in {
      name = "php-fpm-${name}";
      value = {
        description = "PHP FastCGI Process Manager (${name})";
        after = [ "local-fs.target" ];
        wantedBy = [ "multi-user.target" ];
        preStart = ''
          mkdir -p -- '${cfg.home}' '${cfg.logDir}'
          rm -f    -- '${cfg.pool.listen.socket}'
          chown -Rc '${cfg.user}:${cfg.user}' -- '${cfg.home}'
          chmod -Rc u=rwX,g=rX,o= -- '${cfg.home}'
        '';
        serviceConfig = {
          ExecStart = exec;
          KillMode = "mixed";
          PermissionsStartOnly = true;
          Restart = "always";
          User = cfg.user;
        };
      };
    };

in {

  options.nixsap.apps.php-fpm = default {}
    (attrsOf (submodule( { config, name, ... }: {
      options = {
        home = mkOption {
          description = "Directory with logs and the socket";
          type = path;
          default = "/php-fpm/${name}";
        };
        logDir = mkOption {
          description = "Directory with logs. This is convenient read-only option";
          type = path;
          readOnly = true;
          default = "${config.home}/log";
        };
        user = mkOption {
          description = "User to run as";
          type = str;
          default = "php-fpm-${name}";
        };
        package = mkOption {
          description = "PHP package to use FPM from";
          type = package;
          default = pkgs.php;
        };
        php-ini = mkOption {
          description = "php.ini file to pass to php-fpm";
          type = nullOr path;
          default = null;
        };


        global = {
          emergency_restart_interval = optional int;
          emergency_restart_threshold = optional int;
          error_log = readonly "${config.logDir}/error.log" path;
          log_level = optional (enum ["alert" "error" "warning" "notice" "debug"]);
          process_control_timeout = optional int;
          rlimit_core = optional int;
          rlimit_files = optional int;

          process = {
            max      = optional int;
            priority = optional int;
          };
        };

        pool = {
          catch_workers_output      = optional bool;
          chdir                     = optional path;
          clear_env                 = optional bool;
          env                       = default {} (attrsOf str);
          php_admin_flag            = default {} (attrsOf bool);
          php_admin_value           = default {} (attrsOf (either str int));
          php_flag                  = default {} (attrsOf bool);
          php_value                 = default {} (attrsOf (either str int));
          request_terminate_timeout = optional int;
          rlimit_core               = optional int;
          rlimit_files              = optional int;
          listen = {
            acl_groups = optional str;
            backlog    = optional int;
            socket     = readonly "${config.home}/sock" path;
          };
          pm = {
            max_children      = mandatory int;
            max_requests      = optional int;
            max_spare_servers = optional int;
            min_spare_servers = optional int;
            start_servers     = optional int;
            status_path       = optional path;
            strategy          = mandatory (enum ["static" "ondemand" "dynamic"]);
          };
          ping = {
            path     = optional path;
            response = optional str;
          };
        };
      };
    })));

  config = mkIf ({} != instances) {
    nixsap.apps.logrotate.conf = mapAttrs' mkLogRotate instances;
    nixsap.system.users.daemons = users;
    systemd.services = mapAttrs' mkService instances;
  };
}

