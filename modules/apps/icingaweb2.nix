{ config, pkgs, lib, ... }:

let

  inherit (lib)
    any attrNames concatMapStringsSep concatStringsSep filterAttrs
    genAttrs hasPrefix isString mapAttrsToList mkDefault
    mkEnableOption mkIf mkOption mkOptionType mkOverride optionalString
    recursiveUpdate ;
  inherit (lib.types)
    attrsOf bool either enum int lines listOf nullOr package path
    str submodule unspecified ;

  localIcinga = config.nixsap.apps.icinga2.enable;

  cfg = config.nixsap.apps.icingaweb2;

  attrs = opts: submodule { options = opts; };
  mandatory = t: mkOption { type = t; };
  optional = t: mkOption { type = nullOr t; default = null; };
  default = d: t: mkOption { type = t; default = d; };
  explicit = filterAttrs (n: v: n != "_module" && v != null);
  show = v: optionalString (v != null) (toString v);

  permission =
    let
      allowed =
        [
          "config/authentication/groups"
          "config/authentication/roles/show"
          "config/authentication/users"
          "module"
          "monitoring/command"
        ];
    in mkOptionType {
      name = "string starting with one of ${concatMapStringsSep ", " (s: ''"${s}"'') allowed}";
      check = x: isString x && any (p: hasPrefix p x) allowed;
    };

  role = attrs {
    users = default [] (listOf str);
    groups = default [] (listOf str);
    permissions = mandatory (listOf permission);
    objects = mandatory str;
  };

  database = attrs {
    db       = mandatory str;
    host     = mandatory str;
    passfile = optional path;
    port     = optional int;
    type     = mandatory (enum [ "mysql" ]);
    user     = mandatory str;
  };

  configIni = pkgs.writeText "config.ini" ''
    [global]
    show_stacktraces = "${if cfg.stacktrace then "1" else "0"}"
    config_backend = "db"
    config_resource = "icingaweb2db"

    [logging]
    level = "${cfg.logLevel}"
    ${if cfg.log == "syslog" then ''
      log = "syslog"
      application = "icingaweb2"
     '' else ''
      log = "file"
      file = "${cfg.log}"
     ''
    }
  '';

  # XXX Livestatus is not supported by IcingaWeb2 (2.1.0)
  # https://dev.icinga.org/issues/8254
  # "We'll postpone this issue because Icinga 2.4 will introduce
  #  an API for querying monitoring data. Maybe we drop support
  #  for Livestatus completely"
  modules.monitoring.backendsIni = pkgs.writeText "backends.ini" ''
    [icinga2]
    type = "ido"
    resource = "icinga2db"
  '';

  modules.monitoring.configIni = pkgs.writeText "config.ini" ''
    [security]
    protected_customvars = "${concatStringsSep "," cfg.protectedCustomVars}"
  '';

  modules.monitoring.commandtransportsIni = pkgs.writeText "commandtransports.ini" ''
    ${optionalString localIcinga ''
      [local]
      transport = "local"
      path = "${config.nixsap.apps.icinga2.commandPipe}"
      ''
    }
  '';

  groupsIni = pkgs.writeText "groups.ini" (
    optionalString (cfg.authentication == "database") ''
      [database]
      backend = "db"
      resource = "icingaweb2db"
    ''
  );

  authenticationIni = pkgs.writeText "authentication.ini" (
    if cfg.authentication == "sproxy" then ''
      [sproxy]
      backend = "sproxy"
    '' else ''
      [database]
      backend = "db"
      resource = "icingaweb2db"
    ''
  );

  rolesIni = pkgs.writeText "roles.ini" ''
    [root]
    users = "root"
    permissions = "config/authentication/roles/show, config/authentication/users/*, config/authentication/groups/*, module/*, monitoring/command/*"

    ${
      concatStringsSep "\n\n" (
        mapAttrsToList (n: s: ''
          [${n}]
          users = "${concatStringsSep ", " s.users}"
          groups = "${concatStringsSep ", " s.groups}"
          permissions = "${concatStringsSep ", " s.permissions}"
          ${optionalString (s.objects != null) ''
            monitoring/filter/objects = "${s.objects}"
            ''}
        '') (explicit cfg.roles)
      )
    }
  '';

  mkResource = name: opts:
    let
      mkDB = ''
        cat <<'__EOF__'

        [${name}]
        type = "db"
        db = "${opts.type}"
        dbname = "${opts.db}"
        host = "${opts.host}"
        port = "${show opts.port}"
        username = "${opts.user}"
        __EOF__
        ${optionalString (opts.passfile != null) ''
          pwd=$(cat '${opts.passfile}')
          printf 'password="%s"\n' "$pwd"
        ''}
      '';
    in if opts.type == "mysql" then mkDB
       else "";

  genResourcesIni = pkgs.writeBashScript "resources" (concatStringsSep "\n" (
    mapAttrsToList mkResource (explicit cfg.resources)
  ));

  defaultPool = {
    listen.owner = config.nixsap.apps.nginx.user;
    pm.max_children = 10;
    pm.max_requests = 1000;
    pm.max_spare_servers = 5;
    pm.min_spare_servers = 3;
    pm.strategy = "dynamic";
  };

  configureFiles = ''
    set -euo pipefail
    umask 0277
    mkdir -p '${cfg.configDir}'
    ${pkgs.findutils}/bin/find \
      ${cfg.configDir} \
      -mindepth 1 -maxdepth 1 \
      -not -name dashboards \
      -not -name preferences \
      -exec rm -rf '{}' \; || true

    mkdir -p '${cfg.configDir}/dashboards'
    mkdir -p '${cfg.configDir}/preferences'
    mkdir -p '${cfg.configDir}/enabledModules'
    mkdir -p '${cfg.configDir}/modules/monitoring'

    ln -sf '${pkgs.icingaweb2}/modules/monitoring' '${cfg.configDir}/enabledModules/monitoring'
    ln -sf '${pkgs.icingaweb2}/modules/translation' '${cfg.configDir}/enabledModules/translation'
    ${genResourcesIni} > '${cfg.configDir}/resources.ini'
    ln -sf '${authenticationIni}' '${cfg.configDir}/authentication.ini'
    ln -sf '${configIni}' '${cfg.configDir}/config.ini'
    ln -sf '${groupsIni}' '${cfg.configDir}/groups.ini'
    ln -sf '${rolesIni}' '${cfg.configDir}/roles.ini'

    ln -sf '${modules.monitoring.backendsIni}' \
           '${cfg.configDir}/modules/monitoring/backends.ini'

    ln -sf '${modules.monitoring.configIni}' \
           '${cfg.configDir}/modules/monitoring/config.ini'

    ln -sf '${modules.monitoring.commandtransportsIni}' \
           '${cfg.configDir}/modules/monitoring/commandtransports.ini'

    chmod u=rX,g=,o= '${cfg.configDir}'
    chmod -R u=rwX,g=,o= '${cfg.configDir}/dashboards'
    chmod -R u=rwX,g=,o= '${cfg.configDir}/preferences'
    chown -R icingaweb2:icingaweb2 '${cfg.configDir}'
  '';

  configureDB = with cfg.resources.icingaweb2db;
    let
      mkMyCnf = pkgs.writeBashScript "my.cnf.sh" ''
        cat <<'__EOF__'
        [client]
        host = ${host}
        ${optionalString (port != null) "port = ${toString port}"}
        user = ${user}
        __EOF__
        ${optionalString (passfile != null) ''
          pwd=$(cat '${passfile}')
          printf 'password = %s\n' "$pwd"
        ''}
      '';
    in pkgs.writeBashScript "configureDB" ''
      set -euo pipefail
      cnf=$(mktemp)
      trap 'rm -f "$cnf"' EXIT
      chmod 0600 "$cnf"
      ${mkMyCnf} > "$cnf"
      #shellcheck disable=SC2016
      while ! mysql --defaults-file="$cnf" -e 'CREATE DATABASE IF NOT EXISTS `${db}`'; do
        sleep 5s
      done
      tt=$(mysql --defaults-file="$cnf" -N -e 'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = "${db}"')
      if [ "$tt" -eq 0 ]; then
        mysql --defaults-file="$cnf" -v '${db}' < '${pkgs.icingaweb2}/etc/schema/mysql.schema.sql'
        ${optionalString (cfg.initialRootPasswordHash != "") ''
          #shellcheck disable=SC2016
          mysql --defaults-file="$cnf" -e \
            'INSERT INTO icingaweb_user (name, active, password_hash) VALUES ("root", 1, "${cfg.initialRootPasswordHash}")' '${db}'
          ''
        }
      fi
    '';

  keys = [ cfg.resources.icingaweb2db.passfile
           cfg.resources.icinga2db.passfile ];

in {

  options.nixsap.apps.icingaweb2 = {
    enable = mkEnableOption "Icinga Web 2";
    user = mkOption {
      description = ''
        The user the PHP-FPM pool runs as. And the owner of files.
      '';
      default = "icingaweb2";
      type = str;
    };
    nginxServer = mkOption {
      type = lines;
      default = "";
      example = ''
        listen 8080;
        server_name icinga.example.net;
      '';
    };
    configDir = mkOption {
      description = "Where to put config files. This directory will be created if does not exist.";
      type = path;
      default = "/icingaweb2";
    };
    php-fpm = {
      package = mkOption {
        description = "PHP package to use";
        type = package;
        default = pkgs.php;
      };
      pool = mkOption {
        description = "Options for the PHP FPM pool";
        type = attrsOf unspecified;
        default = {};
      };
    };

    resources = mkOption {
      description = "Composes resources.ini";
      type = attrs {
        icingaweb2db = mkOption {
          description = "Database for Icinga Web 2 settings";
          type = database;
        };
        icinga2db = mkOption {
          description = "Icinga2 database (read-only)";
          type = database;
        };
      };
    };

    authentication = mkOption {
      description = ''
        Authentication backend: either IcingaWeb2 database or Sproxy.
      '';
      type = enum [ "sproxy" "database" ];
      default = "database";
    };

    protectedCustomVars = mkOption {
      description = ''
        Icinga2 custom variables to be masked in WebUI.
        This can used for example to hide passwords. Wildcard are allowed.
      '';
      type = listOf str;
      default = [ "*pass*" "*pw*" "community" "http*auth_pair" ];
    };

    roles = mkOption {
      description = "Composes roles.ini";
      type = attrsOf role;
      default = {};
      example = {
        devops = {
          groups = [ "devops" ];
          permissions = [ "module/*" "monitoring/command/*" ];
          objects = "*";
        };
        all = {
          groups = [ "all" ];
          permissions = [ "module/*" ];
          objects = "hostgroup_name=Shops";
        };
      };
    };

    initialRootPasswordHash = mkOption {
      description = ''
        Initial root password for icingaweb2db.
        Use <literal>openssl passwd -1 mysecret</literal>
        to generate this hash. It is used only when database
        does not exist. So you may choose not to keep/commit
        this hash at all. You better change the root password
        after the first login.
      '';
      type = str;
      default = "";
    };

    stacktrace = mkOption {
      description = "whether to show PHP stacktraces";
      type = bool;
      default = false;
    };
    log = mkOption {
      type = either path (enum [ "syslog" ]);
      default = "syslog";
    };
    logLevel = mkOption {
      type = enum [ "INFO" "WARNING" "ERROR" "CRITICAL" "DEBUG" ];
      default = "WARNING";
    };
  };

  config = mkIf cfg.enable {
    nixsap.deployment.keyrings.root = keys;
    users.users.icingaweb2.extraGroups = mkIf localIcinga [ config.nixsap.apps.icinga2.commandGroup ];

    nixsap.apps.php-fpm.icingaweb2 = mkOverride 0 {
      inherit (cfg.php-fpm) package;
      pool = recursiveUpdate defaultPool (cfg.php-fpm.pool // { user = cfg.user ;});
    };

    nixsap.apps.nginx.conf.http.servers.icingaweb2 = ''
      ${cfg.nginxServer}

      root ${pkgs.icingaweb2}/public;
      index index.php;
      try_files $1 $uri $uri/ /index.php$is_args$args;

      location ~ ^/index\.php(.*)$ {
        fastcgi_pass unix:${config.nixsap.apps.php-fpm.icingaweb2.pool.listen.socket};
        fastcgi_index index.php;
        include ${pkgs.nginx}/conf/fastcgi_params;
        fastcgi_param SCRIPT_FILENAME ${pkgs.icingaweb2}/public/index.php;
        fastcgi_param ICINGAWEB_CONFIGDIR ${cfg.configDir};
        fastcgi_param REMOTE_USER $remote_user;
      }
    '';

    systemd.services.icingaweb2cfg = {
      description = "configure Icinga Web 2";
      after = [ "network.target" "local-fs.target" "keys.target" ];
      wants = [ "keys.target" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ mysql ];
      preStart = configureFiles;
      serviceConfig = {
        ExecStart = configureDB;
        PermissionsStartOnly = true;
        RemainAfterExit = true;
        User = "icingaweb2";
      };
    };
  };
}

