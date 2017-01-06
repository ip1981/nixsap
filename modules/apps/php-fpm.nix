{ config, pkgs, lib, ... }:

let

  inherit (builtins)
    filter isAttrs isBool ;
  inherit (lib)
    concatStringsSep filterAttrs foldl hasPrefix
    mapAttrsToList mkIf mkOption types ;
  inherit (types)
    attrsOf bool either enum int nullOr package path str
    submodule ;

  explicit = filterAttrs (n: v: n != "_module" && v != null);
  concatNonEmpty = sep: list: concatStringsSep sep (filter (s: s != "") list);

  attrs = opts: submodule { options = opts; };
  default = d: t: mkOption { type = t; default = d; };
  mandatory = t: mkOption { type = t; };
  optional = t: mkOption { type = nullOr t; default = null; };

  instances = explicit (config.nixsap.apps.php-fpm);

  users = mapAttrsToList (_: v: v.pool.user) instances;

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
        if k == "php-ini" || k == "pool" || k == "package" then ""
        else if isAttrs v then mkGroup k v ""
        else "${k} = ${show v}";

      conf = pkgs.writeText "php-fpm-${name}.conf" ''
        [global]
        daemonize = no
        ${concatNonEmpty "\n" (mapAttrsToList mkGlobal (explicit cfg))}

        [pool]
        ${concatNonEmpty "\n" (mapAttrsToList mkPool (explicit cfg.pool))}
      '';
      exec = "${cfg.package}/bin/php-fpm --fpm-config ${conf} "
           + ( if cfg.php-ini != null
               then "--php-ini ${cfg.php-ini}"
               else "--no-php-ini" );
    in {
      "php-fpm-${name}" = {
        description = "PHP FastCGI Process Manager (${name})";
        after = [ "local-fs.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = exec;
          Restart = "always";
        };
      };
    };

in {

  options.nixsap.apps.php-fpm = default {}
    (attrsOf (submodule( { config, name, ... }: {
      options = {
        package = default pkgs.php package;
        emergency_restart_interval = optional int;
        emergency_restart_threshold = optional int;
        error_log = default "/var/log/php-fpm-${name}.log" path;
        log_level = optional (enum ["alert" "error" "warning" "notice" "debug"]);
        php-ini = optional path;
        process_control_timeout = optional int;
        rlimit_core = optional int;
        rlimit_files = optional int;

        process = optional (attrs {
          max      = optional int;
          priority = optional int;
        });

        pool = default {} (submodule({
          options = {
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
            user                      = default "php-fpm-${name}" str;
            listen = default {} (attrs {
              acl_groups = optional str;
              backlog    = optional int;
              group      = optional str;
              mode       = optional str;
              owner      = default config.pool.user str;
              socket     = default "/run/php-fpm-${name}.sock" path;
            });
            pm = mandatory (attrs {
              max_children      = mandatory int;
              max_requests      = optional int;
              max_spare_servers = optional int;
              min_spare_servers = optional int;
              start_servers     = optional int;
              status_path       = optional path;
              strategy          = mandatory (enum ["static" "ondemand" "dynamic"]);
            });
            ping = optional (attrs {
              path     = optional path;
              response = optional str;
            });
          };
        }));
      };
    })));

  config = mkIf ({} != instances) {
    nixsap.system.users.daemons = users;
    systemd.services = foldl (a: b: a//b) {} (mapAttrsToList mkService instances);
  };
}

