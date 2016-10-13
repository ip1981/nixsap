{ config, pkgs, lib, ... }:
let
  inherit (builtins)
    attrNames filter isBool isInt isList isPath isString length replaceStrings
    toString ;

  inherit (lib)
    mkOption mkEnableOption mkIf types toUpper unique
    optionalString hasPrefix concatStringsSep splitString flatten
    concatMapStrings concatMapStringsSep concatStrings mapAttrsToList filterAttrs;

  inherit (types)
    attrsOf either int lines listOf package str submodule ;

  cfg = config.nixsap.apps.mariadb;

  getDirs = l: map dirOf (filter (p: p != null && hasPrefix "/" p) l);
  mydirs = [ cfg.mysqld.datadir ] ++ getDirs [ cfg.mysqld.log_bin cfg.mysqld.relay_log ];
  explicit = filterAttrs (n: v: n != "_module" && v != null);
  hasMasters = (explicit cfg.replicate) != {};
  concatNonEmpty = sep: list: concatStringsSep sep (filter (s: s != "") list);

  # XXX /run/mysqld/mysqld.sock is the default socket
  rundir   = "/run/mysqld";
  initFile = pkgs.writeText "init" ''
    CREATE USER IF NOT EXISTS '${cfg.user}'@'localhost' IDENTIFIED VIA unix_socket;
    GRANT ALL ON *.* TO '${cfg.user}'@'localhost' WITH GRANT OPTION;
  '';

  mkIgnoreTablesList = quotes: { databases, ignore-tables, ... }:
    let
      q = optionalString quotes "`";
      hasDot = t: 2 == length (splitString "." t);
      all-tbl = filter (t: ! hasDot t) ignore-tables;
      db-tbl = (filter hasDot ignore-tables) ++
                flatten (map (t: map (d: "${q}${d}${q}.${q}${t}${q}") databases) all-tbl);
    in unique db-tbl;

  mkEntry = name: value:
    let
      showList = l: concatMapStringsSep "," (toString) (unique l);
      optimizer_switch = a:
        showList (mapAttrsToList (n: v:
            "${n}=${if v then "on" else "off"}"
          ) (explicit a));
    in if hasPrefix "skip" name then (optionalString value name)
       else if name == "optimizer_switch" then "${name} = ${optimizer_switch value}"
       else if isBool value then "${name} = ${if value then "ON" else "OFF"}"
       else if isInt value then "${name} = ${toString value}"
       else if isList value then "${name} = ${showList value}"
       else if isString value then "${name} = ${value}"
       else abort "Unrecognized option ${name}";

  show = n: v:
         if isBool v then (if v then "1" else "0")
    else if isInt v then toString v
    else if isString v then "'${v}'"
    else if isPath v then "'${v}'"
    else abort "Unrecognized option ${n}";

  mkReplOpt = ch: args@{databases, ignore-databases, ...}:
    let wild_do_table = concatMapStringsSep "\n" (d:
                    "${ch}.replicate_wild_do_table = ${d}.%"
                   ) databases;
        ignore_table = concatMapStringsSep "\n" (t:
                    "${ch}.replicate_ignore_table = ${t}"
                   ) (mkIgnoreTablesList false args);
        ignore_db = concatMapStringsSep "\n" (d:
                    "${ch}.replicate_ignore_db = ${d}"
                   ) ignore-databases;
    in ''
      ${ignore_db}
      ${ignore_table}
      ${wild_do_table}
    '';

  mkDynamicReplOpt = ch: args@{databases, ignore-databases, ...}:
    ''
      SET default_master_connection = "${ch}";
      SET GLOBAL replicate_ignore_db = "${concatStringsSep "," ignore-databases}";
      SET GLOBAL replicate_wild_do_table = "${concatMapStringsSep "," (d: "${d}.%") databases}";
      SET GLOBAL replicate_ignore_table = "${concatMapStringsSep "," (t: "${t}") (mkIgnoreTablesList false args)}";
    '';

  replCnf = pkgs.writeText "mysqld-repl.cnf" ''
      [mysqld]
      ${concatNonEmpty "\n" (mapAttrsToList mkReplOpt (explicit cfg.replicate))}
    '';

  mysqldCnf =
    if hasMasters && (cfg.mysqld.server_id == null || cfg.mysqld.server_id < 1)
    then throw "Misconfigured slave: server_id was not set to a positive integer"
    else pkgs.writeText "mysqld.cnf" ''
      [mysqld]
      basedir = ${cfg.package}
      init_file = ${initFile}
      pid_file = ${rundir}/mysqld.pid
      plugin_load = unix_socket=auth_socket.so
      plugin_load_add = server_audit=server_audit.so
      ${concatNonEmpty "\n" (mapAttrsToList mkEntry (explicit cfg.mysqld))}
      ${optionalString hasMasters "!include ${replCnf}"}
    '';

  await = pkgs.writeBashScript "await" ''
    count=0
    while ! mysql -e ';' 2>/dev/null; do
      if ! (( count % 60 )); then
        mysql -e ';'
      fi
      sleep 5s
      (( ++count ))
    done
  '';

  conf = pkgs.writeBashScriptBin "mariadb-conf"
    ''
      set -euo pipefail
      trap "" SIGHUP
      ${await}
      ${optionalString (cfg.configure' != "") ''
        tmp=$(mktemp)
        trap 'rm -f "$tmp"' EXIT
        mysql -N mysql < ${pkgs.writeText "mariadb-make-conf2.sql" cfg.configure'} > "$tmp"
        mysql -v mysql < "$tmp"
      ''}
      mysql -v mysql < ${pkgs.writeText "mariadb-conf.sql" cfg.configure}
    '';

  maintenance = pkgs.writeBashScriptBin "mariadb-maint" ''
    set -euo pipefail
    trap "" SIGHUP
    ${await}
    ${optionalString hasMasters "mysql -e 'STOP ALL SLAVES SQL_THREAD'"}
    mysql_upgrade --user=${cfg.user}
    mysql_tzinfo_to_sql "$TZDIR" | mysql mysql
    mysql mysql < ${./procedures.sql}
    cat <<'__SQL__' | mysql
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test%';
    DELETE FROM mysql.user WHERE User='${cfg.user}' AND Host NOT IN ('localhost');
    DELETE FROM mysql.user WHERE User=${"''"};
    DELETE FROM mysql.user WHERE User='root';
    DELETE FROM mysql.proxies_priv WHERE User='root';
    FLUSH PRIVILEGES;
    ${concatMapStrings (db: ''
    CREATE DATABASE IF NOT EXISTS `${db}`;
    '') cfg.databases}
    __SQL__
    ${optionalString hasMasters "mysql -e 'START ALL SLAVES'"}
  '';

  changeMaster =
    let
      do = ch: opts:
        let
          masterOptions = filterAttrs (n: _: n != "password-file") (explicit opts.master);
          masterOptionName = n: ''MASTER_${toUpper (replaceStrings ["-"] ["_"] n)}'';
          changeMaster = "CHANGE MASTER '${ch}' TO " + (concatStringsSep ", " (mapAttrsToList (n: v:
              "${masterOptionName n}=${show n v}") masterOptions)) + ";";
        in pkgs.writeBashScript "change-master-${ch}" ''
          cat <<'__SQL__'
          ${changeMaster}
          ${mkDynamicReplOpt ch opts}
          __SQL__
          ${optionalString (opts.master.password-file != null) ''
            pwd=$(cat '${opts.master.password-file}')
            echo "CHANGE MASTER '${ch}' TO MASTER_PASSWORD='$pwd';"''}
        '';

    in pkgs.writeBashScript "changeMaster" (
      concatStringsSep "\n" (mapAttrsToList (ch: opts: ''
        [ "$1" = ${ch} ] && exec ${do ch opts}
      '') (explicit cfg.replicate))
    );

  importDump =
    let
      do = ch: opts:
        let
          cnf = "${rundir}/master-${ch}.cnf";
          mysqldumpOptions = filterAttrs (n: _: n != "password-file" && n != "path")
            (explicit opts.mysqldump);
          binary = if opts.mysqldump.path != null then opts.mysqldump.path else "mysqldump";
          mysqldump = concatStringsSep " " (
              [ binary "--defaults-file=${cnf}" "--skip-comments" "--force" ]
              ++ mapAttrsToList (n: v: "--${n}=${show n v}") mysqldumpOptions);
          databases = concatStringsSep " " ([ "--databases" ] ++ opts.databases);
          ignore-tables = concatMapStringsSep " " (t: "--ignore-table=${t}") (mkIgnoreTablesList false opts);
        in pkgs.writeBashScript "import-${ch}" ''
          set -euo pipefail
          touch '${cnf}'
          trap "rm -f '${cnf}'" EXIT
          trap "exit 255" TERM INT
          chmod 0600 '${cnf}'
          ${optionalString (opts.mysqldump.password-file != null) ''
            printf '[client]\npassword=' > '${cnf}'
            cat '${opts.mysqldump.password-file}' >> '${cnf}'
          ''}
          echo 'SET default_master_connection="${ch}";'
          ${optionalString (!cfg.mysqld.log_slave_updates) "echo 'SET sql_log_bin=0;'"}
          ${mysqldump} --master-data=0 --no-data ${databases}
          ${mysqldump} --master-data=1 ${ignore-tables} ${databases}
        '';
    in pkgs.writeBashScript "importDump" (
      concatStringsSep "\n" (mapAttrsToList (ch: opts: ''
        [ "$1" = ${ch} ] && exec ${do ch opts}
      '') (explicit cfg.replicate))
    );

  watchdog = pkgs.writeBashScript "slave-watchdog"
    (import ./slave-watchdog.nix {inherit importDump changeMaster;});

  slaves =
    let
      channels = attrNames (explicit cfg.replicate);
      truncate = ch: concatMapStringsSep "\n"
        (t: "TRUNCATE TABLE ${t};") (mkIgnoreTablesList true cfg.replicate.${ch});
      truncateIgnored = pkgs.writeText "truncate.sql"
        (concatMapStringsSep "\n" truncate channels);
      old = "${rundir}/channels";
      new = pkgs.writeText "channels.new" (concatMapStringsSep "\n"
        (ch: "${ch}:${cfg.replicate.${ch}.master.host}") channels);
    in pkgs.writeBashScriptBin "mariadb-slaves" ''
      set -euo pipefail
      rm -f ${rundir}/*.lock
      ${await}
      touch ${old}
      chmod 0600 ${old}
      trap 'rm -f ${old}' EXIT
      mysql -e 'SHOW ALL SLAVES STATUS\G' \
        | awk '/Connection_name:/ {printf $2 ":"}; /Master_Host:/ {print $2}' \
        | sort > ${old}
      obsolete=$(comm -23 ${old} ${new} | cut -d: -f1)
      for ch in $obsolete; do
        echo "Deleting obsolete slave $ch"
        mysql -e "CALL mysql.resetSlave('$ch')"
      done
      ${optionalString hasMasters ''
        mysql -f < ${truncateIgnored} || echo '(errors ignored)' >&2
        export PARALLEL_SHELL=${pkgs.bash}/bin/bash
        export HOME='${rundir}'
        {
          while true; do
            printf "${concatStringsSep "\\n" channels}\n"
            sleep 10m
          done
        } | parallel \
            --halt-on-error 0 \
            --jobs '${toString cfg.slaveWatchdogs}' \
            --line-buffer \
            --no-notice \
            --tagstr '* {}:' \
            'flock -E 0 -n ${rundir}/master-{}.lock ${watchdog} {}'
        ''
      }
    '';

  all-keys = flatten (
      mapAttrsToList (ch: {master, mysqldump, ...}:
        [ master.password-file
          master.ssl-key
          mysqldump.password-file
          mysqldump.ssl-key
        ]) (explicit cfg.replicate)
    ) ++ [ cfg.mysqld.ssl_key ];

in {

  imports = [ ./roles.nix ];

  options.nixsap = {
    apps.mariadb = {
      enable = mkEnableOption "MySQL";

      user = mkOption {
        description = "User to run as";
        default = "mariadb";
        type = str;
      };

      package = mkOption {
        description = "MariaDB Package (10.1.x)";
        type = package;
        default = pkgs.mariadb;
      };

      replicate = mkOption {
        type = attrsOf (submodule (import ./replicate.nix));
        default = {};
        description = "Replication channels";
      };

      slaveWatchdogs = mkOption {
        type = either str int;
        default = "80%";
        description = ''
          Number of parallel slave monitoring and recovery processes.
          In the format of GNU Parallel, e. g. "100%", -1. +3, 7, etc.
        '';
      };

      mysqld = mkOption {
        type = submodule (import ./mysqld.nix);
        default = {};
        description = "mysqld options";
      };

      databases = mkOption {
        description = "Databases to create if not exist";
        type = listOf str;
        default = [];
      };

      configure = mkOption {
        type = lines;
        default = "";
        description = ''
          Any SQL statements to execute, typically GRANT / REVOKE etc.
          This is executed in contect of the `mysql` database.
        '';
        example = ''
          CREATE USER IF NOT EXISTS 'icinga'@'%' IDENTIFIED BY PASSWORD '*AC8C3BDA823EECFF90A8381D554232C7620345B3';
          GRANT USAGE ON *.* TO 'icinga'@'%' REQUIRE SSL;
          REVOKE ALL, GRANT OPTION FROM 'icinga'@'%';
          GRANT PROCESS, REPLICATION CLIENT, SHOW DATABASES ON *.* TO 'icinga'@'%';
          GRANT SELECT ON mysql.* TO 'icinga'@'%';
        '';
      };

      configure' = mkOption {
        type = lines;
        default = "";
        internal = true;
        description = ''
          SQL statements that generate other SQL statements to be executed.
          Those generated statements will be executed before `configure`.
        '';
        example = ''
          SELECT CONCAT('GRANT SELECT ON `', table_schema, '`.`', table_name, '` TO \'_oms_package_vn\';')
          FROM information_schema.tables WHERE
          table_schema LIKE '%oms_live_vn' AND
          table_name LIKE 'oms_package%';
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    nixsap.system.users.daemons = [ cfg.user ];
    nixsap.deployment.keyrings.${cfg.user} = all-keys;

    nixsap.apps.mariadb.configure = concatMapStringsSep "\n"
      (n: ''
        CREATE USER IF NOT EXISTS '${n}'@'localhost' IDENTIFIED VIA unix_socket;
        REVOKE ALL, GRANT OPTION FROM '${n}'@'localhost';
        GRANT SELECT, EXECUTE ON mysql.* TO '${n}'@'localhost';
        GRANT PROCESS, REPLICATION CLIENT, SHOW DATABASES, SHOW VIEW ON *.* TO '${n}'@'localhost';
        '') config.nixsap.system.users.sysops;

    systemd.services.mariadb-slaves = {
      description = "MariaDB slaves watchdog";
      requires = [ "mariadb.service" ];
      after = [ "mariadb.service" "mariadb-maintenance.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ gnused gawk cfg.package utillinux parallel ];
      serviceConfig = {
        ExecStart = "${slaves}/bin/mariadb-slaves";
        User = cfg.user;
      } // (if hasMasters
        then {
          Restart = "always";
        }
        else {
          Type = "oneshot";
        });
    };

    systemd.services.mariadb-maintenance = {
      description = "MariaDB maintenance";
      after = [ "mariadb.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ cfg.package ];
      serviceConfig = {
        ExecStart = "${maintenance}/bin/mariadb-maint";
        User = cfg.user;
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.mariadb-conf = {
      description = "MariaDB configuration";
      after = [ "mariadb.service" "mariadb-maintenance.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ cfg.package ];
      serviceConfig = {
        ExecStart = "${conf}/bin/mariadb-conf";
        User = cfg.user;
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.mariadb = {
      description = "MariaDB server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "keys.target" ];
      after = [ "keys.target" "network.target" "local-fs.target" ];
      path = [ pkgs.inetutils ];
      environment = {
        UMASK = "0640";
        UMASK_DIR = " 0750";
      };
      preStart = ''
        mkdir -p '${rundir}'
        chmod 0700 '${rundir}'
        mkdir -p ${concatMapStringsSep " " (d: "'${d}'") mydirs}
        if [ ! -f '${cfg.mysqld.datadir}/mysql/user.MYI' ]; then
          rm -rf '${cfg.mysqld.datadir}/mysql'
          ${cfg.package}/bin/mysql_install_db --defaults-file=${mysqldCnf}
        fi
        chown -Rc '${cfg.user}':$(id -g -n '${cfg.user}') '${rundir}' ${concatMapStringsSep " " (d: "'${d}'") mydirs}
        chmod -Rc u=rwX,g=rX,o= ${concatMapStringsSep " " (d: "'${d}'") mydirs}
        chmod 0755 '${rundir}'
      '';

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/mysqld --defaults-file=${mysqldCnf}";
        PermissionsStartOnly = true;
        User = cfg.user;
        Restart = "always";
        TimeoutSec = 0; # XXX it can take hours to shutdown, and much more to start if you kill shutdown :-D
        LimitNOFILE = "infinity";
        LimitMEMLOCK = "infinity";
        OOMScoreAdjust = -1000;
      };
    };
  };
}
