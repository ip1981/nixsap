{ config, pkgs, lib, ... }:
let

  inherit (builtins)
    match toString ;

  inherit (lib)
    concatMapStrings concatStringsSep filterAttrs foldAttrs filter foldl
    hasPrefix isBool isInt isList isString length mapAttrs' mapAttrsToList
    mkDefault mkIf mkOption nameValuePair types ;

  inherit (types)
    attrsOf lines listOf nullOr package path str submodule ;

  concatNonEmpty = sep: list: concatStringsSep sep (filter (s: s != "") list);
  explicit = filterAttrs (n: v: n != "_module" && v != null);

  instances = explicit config.nixsap.apps.postgresql;
  users = mapAttrsToList (_: v: v.user) instances;

  isFloat = x: match "^[0-9]+(\\.[0-9]+)?$" (toString x) != null;

  keyrings =
    let
      ik = mapAttrsToList (_: i: { "${i.user}" = [ i.server.ssl_key_file ]; } ) instances;
    in foldAttrs (l: r: l ++ r) [] ik;

  mkService = name: opts:
    let
      inherit (opts) user initdb;
      inherit (opts.server) data_directory port hba_file ident_file;
      ident_file_path = pkgs.writeText "${name}-ident_file" ''
                        postgres ${user} postgres
                        ${ident_file}
                      '';
      hba_file_path = pkgs.writeText "${name}-hba_file" ''
                        local all postgres peer map=postgres
                        ${hba_file}
                      '';
      show = n: v: if isBool v then (if v then "yes" else "no")
           else if n == "ident_file" then "'${ident_file_path}'"
           else if n == "hba_file" then "'${hba_file_path}'"
           else if isFloat v then toString v
           else if isString v then "'${v}'"
           else if isList v then "'${concatStringsSep "," v}'"
           else toString v;
      conf = pkgs.writeText "pgsql-${name}.conf" (
        concatStringsSep "\n" (mapAttrsToList (n: v: "${n} = ${show n v}") (explicit opts.server))
      );

      preStart = ''
        mkdir -v -p '${data_directory}'
        chown -R '${user}:${user}' '${data_directory}'
        chmod -R u=rwX,g=,o= '${data_directory}'
      '';

      main = pkgs.writeBashScriptBin "pgsql-${name}" ''
        set -euo pipefail
        if [ ! -f '${data_directory}/PG_VERSION' ]; then
          ${initdb} '${data_directory}'
          rm -f '${data_directory}/'*hba.conf
          rm -f '${data_directory}/'*ident.conf
          rm -f '${data_directory}/postgresql.conf'
        fi
        exec '${opts.package}/bin/postgres' -c 'config_file=${conf}'
      '';

      psql = "${opts.package}/bin/psql -v ON_ERROR_STOP=1 -p${toString port} -U postgres";

      configure =
        let
          create = pkgs.writeText "pgsql-${name}-create.sql" ''
            ${concatMapStrings (r: ''
              SELECT create_role_if_not_exists('${r}');
            '') opts.roles}
            ${concatMapStrings (d: ''
              SELECT create_db_if_not_exists('${d}');
            '') opts.databases}
          '';
        in pkgs.writeBashScriptBin "pgsql-${name}-conf" ''
          set -euo pipefail
          while ! ${psql} -c ';'; do
            sleep 5s
          done
          ${psql} -f ${./functions.pgsql}
          ${psql} -f ${create}
          ${psql} -f ${pkgs.writeText "pgsql-${name}.sql" opts.configure}
        '';

      needConf = (opts.configure != "") || (opts.roles != []) || (opts.databases != []);

    in {
      "pgsql-${name}" = {
        wantedBy = [ "multi-user.target" ];
        wants = [ "keys.target" ];
        after = [ "keys.target" "network.target" "local-fs.target" ];
        inherit preStart;
        serviceConfig = {
          ExecStart = "${main}/bin/pgsql-${name}";
          KillMode = "mixed";
          KillSignal = "SIGINT";
          PermissionsStartOnly = true;
          TimeoutSec = 0;
          User = user;
        };
      };
      "pgsql-${name}-conf" = mkIf needConf {
        wantedBy = [ "multi-user.target" ];
        after = [ "pgsql-${name}.service" ];
        requires = [ "pgsql-${name}.service" ];
        serviceConfig = {
          ExecStart = "${configure}/bin/pgsql-${name}-conf";
          RemainAfterExit = true;
          Type = "oneshot";
          User = user;
        };
      };
    };

  instance = submodule ( { config, name, ... }: {
    options = {
      user = mkOption {
        description = "User to run as. Default is instance name";
        type = str;
        default = "pgsql-${name}";
      };
      roles = mkOption {
        description = ''
          List of roles to be created. These roles will be created if do
          not exist.  That's it. You will have to ALTER these roles and GRANT
          privileges using the `configure` option. Note that if you remove
          roles from this list, they will NOT be deleted from the database.
          You do not need this if this instance is a replica.
        '';
        type = listOf str;
        default = [];
      };
      databases = mkOption {
        description = ''
          List of databases to be created. These databases will be created
          if do not exist.  You do not need this if this instance is a replica.
        '';
        type = listOf str;
        default = [];
      };
      configure = mkOption {
        description = ''
          SQL statements to be executed. This should be idempotent.
          May include creation of roles and databases, granting privileges.
          Usage of PL/pgSQL is hightly encouraged.
          You do not need this if this instance is a replica.
          '';
        type = lines;
        default = "";
        example = ''
          SELECT create_role_if_not_exists('sproxy');
          ALTER ROLE sproxy RESET ALL;
          ALTER ROLE sproxy LOGIN;
          SELECT create_db_if_not_exists('sproxy');
          ALTER DATABASE sproxy OWNER TO sproxy;
        '';
      };
      package = mkOption {
        description = "PostgreSQL package";
        type = package;
        default = pkgs.postgresql;
      };
      server = mkOption {
        description = "PostgreSQL server configuration";
        type = submodule (import ./server.nix);
      };
      initdb = mkOption {
          description = ''
            Specifies the command to initialize data directory.
            This command will be executed after the data directory is created.
            The path to the data directory will be appended to this command.
            '';
          default = "${config.package}/bin/initdb -U postgres";
          example = "\${pkgs.postgresql94}/bin/pg_basebackup ... -R -D";
          type = path;
      };
    };
    config = {
      server = {
        data_directory = mkDefault "/postgresql/${name}";
        syslog_ident = mkDefault "pgsql-${name}";
      };
    };
  });

in {
  options.nixsap.apps.postgresql = mkOption {
    description = "Instances of PostgreSQL.";
    type = attrsOf instance;
    default = {};
  };

  config = {
    nixsap.deployment.keyrings = keyrings;
    systemd.services = foldl (a: b: a//b) {} (mapAttrsToList mkService instances);
    nixsap.system.users.daemons = users;
  };
}
