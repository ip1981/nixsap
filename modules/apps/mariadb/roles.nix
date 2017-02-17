{ config, lib, pkgs, ... }:
let

  inherit (builtins)
    elemAt filter isAttrs isList length ;

  inherit (lib)
    attrNames concatMapStrings concatMapStringsSep concatStrings
    concatStringsSep filterAttrs flatten mapAttrsToList mkIf mkOption mkOrder
    optionalString replaceStrings splitString ;

  inherit (lib.types)
    attrsOf either listOf str submodule ;

  cfg = config.nixsap.apps.mariadb;

  explicit = filterAttrs (n: v: n != "_module" && v != null);

  inherit (config.nixsap.apps.mariadb) roles;
  basicRoles = filterAttrs (_: v: isAttrs v) roles;
  topRoles = filterAttrs (_: v: isList v) roles;
  allRoles = attrNames roles;
  sqlList = concatMapStringsSep ", " (i: "'${i}'");

  concatMapAttrs = f: attrs: concatStrings (mapAttrsToList f attrs);

  schemaName = object: elemAt (splitString "." object) 0;
  isSchema = object:
    let p = splitString "." object;
        n = length p;
    in (n == 1)
    || (n == 2 && (elemAt p 1) == "%")
    || ((elemAt p 1) == "%" && (elemAt p 2) == "%");

  tableName = object: elemAt (splitString "." object) 1;
  isTable = object:
    let p = splitString "." object;
        n = length p;
    in (n == 2 && (elemAt p 1) != "%")
    || (n > 2 && (elemAt p 2) == "%");

  columnName = object: elemAt (splitString "." object) 2;
  isColumn = object:
    let p = splitString "." object;
        n = length p;
    in (n > 2 && (elemAt p 2) != "%");

  grant = role: privileges:
    {
      schemas = concatMapAttrs (priv: objects:
          concatMapStrings (o:
            let
              db = schemaName o;
              p = "${replaceStrings [" "] ["_"] priv}_priv";
            in ''
              SELECT 'GRANT ${priv} ON `${db}`.* TO \'${role}\';'
              FROM information_schema.schemata -- Not really used, but for syntax and locks
              WHERE NOT EXISTS (
                SELECT 1 FROM db
                WHERE db.host = ${"''"} -- role, not user
                AND db.user = '${role}'
                AND '${db}' LIKE db.db
                AND db.${p} = 'Y'
              ) LIMIT 1;
            '') (filter isSchema (flatten [objects]))
        ) (explicit privileges);

      tables = concatMapAttrs (priv: objects:
          concatMapStrings (o: ''
            SELECT CONCAT('GRANT ${priv} ON `', t.table_schema, '`.`', t.table_name, '` TO \'${role}\';')
            FROM information_schema.tables t
            WHERE t.table_schema LIKE '${schemaName o}'
            AND t.table_name LIKE '${tableName o}'
            AND NOT EXISTS (
              SELECT 1 FROM mysql.tables_priv
              WHERE tables_priv.host = ${"''"} -- role, not user
              AND tables_priv.user = '${role}'
              AND tables_priv.db = t.table_schema
              AND tables_priv.table_name = t.table_name
              AND FIND_IN_SET('${priv}', tables_priv.table_priv) > 0
            );
            '') (filter isTable (flatten [objects]))
        ) (explicit privileges);

      columns = concatMapAttrs (priv: objects:
          let colObjs = filter isColumn (flatten [objects]);
          in optionalString ([] != colObjs) (''
            SELECT CONCAT ('GRANT ${priv}(',
                GROUP_CONCAT(DISTINCT c.column_name SEPARATOR ','),
              ') ON `', c.table_schema, '`.`', c.table_name, '` TO \'${role}\';')
            FROM information_schema.columns c WHERE (
          '' + concatMapStringsSep " OR " (o:
              ''
                ( c.table_schema LIKE '${schemaName o}' AND
                  c.table_name LIKE '${tableName o}' AND
                  c.column_name LIKE '${columnName o}')
              '') colObjs
          +
          ''
          ) AND NOT EXISTS (
              SELECT 1 FROM columns_priv
              WHERE columns_priv.host = ${"''"} -- role, not user
              AND columns_priv.user = '${role}'
              AND columns_priv.db = c.table_schema
              AND columns_priv.table_name = c.table_name
              AND columns_priv.column_name = c.column_name
              AND FIND_IN_SET('${priv}', columns_priv.column_priv) > 0
          ) GROUP BY CONCAT(c.table_schema, c.table_name);
          '')
        ) (explicit privileges);
    };

  refreshRolesSQL =
    let
      sql = concatMapAttrs (role: privileges: ''
        ${(grant role privileges).schemas}
        ${(grant role privileges).tables}
        ${(grant role privileges).columns}
      '') basicRoles;
    in pkgs.writeText "refresh-roles.sql" sql;


  # XXX Why not timer? This should run periodically, but,
  # if changed, this also should run on deploy.
  refreshRoles = pkgs.writeBashScriptBin "refreshRoles" ''
    set -euo pipefail

    doze() {
      difference=$(($(date -d "08:00" +%s) - $(date +%s)))
      if [ $difference -lt 0 ]; then
          sleep $((86400 + difference))
      else
          sleep $difference
      fi
    }

    while true; do
      while ! ${cfg.package}/bin/mysql -e ';'; do
        sleep 5s
      done
      tmp=$(mktemp)
      trap 'rm -f "$tmp"' EXIT
      ${cfg.package}/bin/mysql -N mysql < ${refreshRolesSQL} >> "$tmp"
      ${cfg.package}/bin/mysql -v mysql < "$tmp"
      doze
    done
  '';

  configureRoles = ''
    CREATE TEMPORARY TABLE __roles (u CHAR(80));
    ${optionalString (allRoles != []) ''
      INSERT INTO __roles VALUES
        ${concatMapStringsSep "," (r: "('${r}')") allRoles}
        ;
    ''}

    -- Add new roles.
    SELECT CONCAT('CREATE ROLE \''', u, '\';')
    FROM __roles
    LEFT OUTER JOIN user
    ON u = user
    WHERE user IS NULL ;


    CREATE TEMPORARY TABLE __roles_mapping (u CHAR(80), r CHAR(80));
    ${concatMapAttrs (role: subroles: ''
      INSERT INTO __roles_mapping VALUES
      ${concatMapStringsSep "," (r: "('${role}', '${r}')") subroles}
      ;
    '') topRoles}

    -- Add new mappings.
    SELECT CONCAT('GRANT \''', r, '\' TO \''', u, '\';')
    FROM __roles_mapping
    LEFT OUTER JOIN roles_mapping
    ON r = role AND u = user
    WHERE user IS NULL OR role IS NULL ;

    -- Remove old mappings. Empty hosts correspond to roles.
    SELECT CONCAT('REVOKE \''', role, '\' FROM \''', user, '\';')
    FROM __roles_mapping
    RIGHT OUTER JOIN roles_mapping
    ON r = role AND u = user
    WHERE (u IS NULL OR r IS NULL) AND host = ${"''"} ;

    DROP TABLE __roles_mapping;

    -- Remove old roles.
    SELECT CONCAT('DROP ROLE \''', user, '\';')
    FROM __roles
    RIGHT OUTER JOIN user
    ON u = user
    WHERE u IS NULL AND is_role = 'Y' ;

    DROP TABLE __roles;

  '';

  roleType =
    let
      objects = mkOption {
        type = listOf str;
        default = [];
        example = [
          "%bleep.%.created\_at"
          "%bob\_live\_sg.brand\_type"
          "%bob\_live\_sg.catalog%"
          "%bob\_live\_sg.supplier.status"
          "bar.%"
          "beep"
          "foo.%.%"
        ];
      };
      basicRole = submodule {
        options = {
          "ALL"       = objects;
          "ALTER"     = objects;
          "CREATE"    = objects;
          "DELETE"    = objects;
          "DROP"      = objects;
          "INDEX"     = objects;
          "INSERT"    = objects;
          "SELECT"    = objects;
          "SHOW VIEW" = objects;
          "UPDATE"    = objects;
        };
      };
      topRole = listOf str;
    in either basicRole topRole;

in {
  options.nixsap.apps.mariadb = {
    roles = mkOption {
      type = attrsOf roleType;
      default = {};
      description = ''
        Defines MariaDB roles. A role can be a "basic" one or a "top"
        one. The basic roles are granted of regular privileges like SELECT
        or UPDATE, while the top roles are granted of other roles. For basic
        roles MySQL wildcards ("%" and "_") can be used to specify objects
        to be granted on, including databases, tables and columns names. A
        script runs periodically to find all matching objects and grants on
        them. Objects are denoted as "database[.table[.column]]".
      '';
      example = {
        top_role = [ "basic_role" ];
        basic_role = {
          SELECT = [
            "%bob\_live\_sg.brand\_type"
            "%bob\_live\_sg.catalog%"
            "%bob\_live\_sg.supplier.created\_at"
            "%bob\_live\_sg.supplier.id\_supplier"
            "%bob\_live\_sg.supplier.name%"
            "%bob\_live\_sg.supplier.status"
            "%bob\_live\_sg.supplier.type"
            "%bob\_live\_sg.supplier.updated\_at"
          ];
        };
        monitoring = {
          SELECT = [
            "%.%.created_at"
          ];
        };
      };
    };
  };

  config = {
    nixsap.apps.mariadb.configure' = mkOrder 0 configureRoles;

    systemd.services.mariadb-roles = mkIf (basicRoles != {}) {
      description = "refresh MariaDB basic roles";
      after = [ "mariadb-conf.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${refreshRoles}/bin/refreshRoles";
        User = config.nixsap.apps.mariadb.user;
        Restart = "always";
      };
    };
  };
}

