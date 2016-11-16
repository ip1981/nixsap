{ config, pkgs, lib, ... }:
let
  inherit (lib) mkOption mkIf mkDefault mapAttrsToList flatten hasPrefix 
                concatMapStringsSep concatStringsSep optionalString filterAttrs
                splitString removeSuffix;
  inherit (lib.types) bool str int path either enum nullOr listOf attrsOf submodule;
  inherit (builtins) isString isBool isInt isList isPath toString length;

  cfg = config.nixsap.apps.mysqlbackup;
  privateDir = "/run/mysqlbackup";

  mysql = "${pkgs.mysql}/bin/mysql";
  mysqldump = "${pkgs.mysql}/bin/mysqldump";
  s3cmd = "${pkgs.s3cmd}/bin/s3cmd ${optionalString (cfg.s3cfg != null) "-c '${cfg.s3cfg}'"}";

  gpgPubKeys = flatten [ cfg.encrypt ];
  gpg = "${pkgs.gpg}/bin/gpg2";
  pubring = pkgs.runCommand "pubring.kbx" {} ''
    ${gpg} --homedir . --import ${toString gpgPubKeys}
    cp pubring.kbx $out
  '';

  default = d: t: mkOption { type = t; default = d; };
  explicit = filterAttrs (n: v: n != "_module" && v != null);
  mandatory = type: mkOption { inherit type; };
  optional = type: mkOption { type = nullOr type; default = null; };
  sub = options: submodule { inherit options; } ;

  connection = mkOption {
    description = "Connection options used by mysqlbackup";
    type = sub {
      compress               = default true bool;
      host                   = mandatory str;
      max-allowed-packet     = optional int;
      password-file          = optional path;
      port                   = optional int;
      socket                 = optional path;
      ssl                    = optional bool;
      ssl-ca                 = optional path;
      ssl-cert               = optional path;
      ssl-key                = optional path;
      ssl-verify-server-cert = optional bool;
      user                   = optional str;
    };
  };

  databases = mkOption {
    description = "What to dump and what to ignore";
    default = {};
    type = sub {
      like = mkOption {
        description = ''
          Databases to dump. MySQL wildcards (_ and %) are supported.
          Logical OR is applied to all entries.
          '';
        type = either str (listOf str);
        default = "%";
        example = [ "%\\_live\\_%" ];
      };
      not-like = mkOption {
        description = ''
          Databases to skip. MySQL wildcards (_ and %) are supported.
          You don't need to specify `performance_schema` or `information_schema`
          here, they are always ignored. Logical AND is applied to all entries.
          '';
        type = either str (listOf str);
        default = [];
        example = [ "tmp\\_%" "snap\\_%" ];
      };
      empty-tables-like = mkOption {
        description = ''
          Tables to ignore. MySQL wildcards (_ and %) are supported.
          Note that the schemas of these tables will be dumped anyway.
          Each table template can be prefixed with a database template.
          In that case it will be applied to matching databases only,
          instead of all databases'';
        type = either str (listOf str);
        default = [];
        example = [ "bob%.alice\\_message" ];
      };
      skip-tables-like = mkOption {
        description = ''
          Tables to ignore. MySQL wildcards (_ and %) are supported.
          Each table template can be prefixed with a database template.
          In that case it will be applied to matching databases only,
          instead of all databases'';
        type = either str (listOf str);
        default = [];
        example = [ "tmp%" "%\\_backup" ];
      };
    };
  };

  server = submodule ({ name, ... }:
    {
      options = { inherit connection databases; };
      config.connection.host = mkDefault name;
    }
  );

  connectionKeys = flatten (mapAttrsToList (_: s: with s.connection; [ password-file ssl-key ]) cfg.servers);
  keys =  connectionKeys ++ [ cfg.s3cfg ];

  showDatabases = name: server: pkgs.writeText "show-databases-${name}.sql" ''
    SHOW DATABASES WHERE `Database` NOT IN ('information_schema', 'performance_schema', 'tmp', 'innodb')
      AND (${concatMapStringsSep " OR " (e: "`Database` LIKE '${e}'") (flatten [server.databases.like])})
      ${concatMapStringsSep " " (e: "AND `Database` NOT LIKE '${e}'") (flatten [server.databases.not-like])}
      ;
  '';

  defaultsFile = name: server:
    let
      inc = optionalString (server.connection.password-file != null)
            "!include ${privateDir}/cnf/${name}";
      show = n: v:
             if isBool v then (if v then "1" else "0")
        else if isInt v then toString v
        else if isString v then "${v}"
        else if isPath v then "'${v}'"
        else abort "Unrecognized option ${n}";
    in pkgs.writeText "my-${name}.cnf"
      ( concatStringsSep "\n" (
        [ "[client]" ]
        ++ mapAttrsToList (k: v: "${k} = ${show k v}")
           (filterAttrs (k: _: k != "password-file") (explicit server.connection))
        ++ [ "${inc}\n" ]
        )
      );

  listTables = name: server: tables:
    let
      anyDb = s: if 1 == length (splitString "." s)
                 then "%.${s}" else s;
      query = optionalString (0 < length tables) ''
        set -euo pipefail
        db="$1"
        cat <<SQL | ${mysql} --defaults-file=${defaultsFile name server} -N
        SELECT CONCAT(table_schema, '.', table_name) AS tables
        FROM information_schema.tables HAVING tables LIKE '$db.%'
        AND ( ${concatMapStringsSep " OR " (e: "tables LIKE '${e}'")
              (map anyDb tables)} );
        SQL
      '';
    in pkgs.writeBashScript "list-tables-${name}" query;

  job = name: server: pkgs.writeBashScript "job-${name}" ''
    set -euo pipefail
    db=$(basename "$0")
    cd "${cfg.dumpDir}/$DATE"

    dump="$db@${name},$DATE.mysql.xz"
    ${if (gpgPubKeys != []) then ''
      aim="$dump.gpg"
    '' else ''
      aim="$dump"
    ''}

    if ! [ -r "$aim" ]; then
      {
        empty=()

        empty+=( $(${listTables name server server.databases.empty-tables-like} "$db") )
        if [ ''${#empty[@]} -gt 0 ]; then
          tables=( "''${empty[@]/#*./}" )
          ${mysqldump} --defaults-file=${defaultsFile name server} \
            --skip-comments --force --single-transaction \
            --no-data "$db" "''${tables[@]}"
        fi

        empty+=( $(${listTables name server server.databases.skip-tables-like} "$db") )

        if [ ''${#empty[@]} -gt 0 ]; then
          ignoretables+=( "''${empty[@]/#/--ignore-table=}" )
        fi

        ${mysqldump} --defaults-file=${defaultsFile name server} \
          --skip-comments --force --single-transaction \
          "''${ignoretables[@]:+''${ignoretables[@]}}" \
          "$db"
      } | ${pkgs.pxz}/bin/pxz -2 -T2 > "$dump".tmp
      ${pkgs.xz}/bin/xz -t -v "$dump".tmp
      mv "$dump".tmp "$dump"

      ${optionalString (gpgPubKeys != []) ''
        recipient=( $(${gpg} --homedir '${privateDir}/gnupg' -k --with-colons --fast-list-mode | \
          ${pkgs.gawk}/bin/awk -F: '/^pub/{print $5}') )
        r=( "''${recipient[@]/#/-r}" )
        ${gpg} --homedir '${privateDir}/gnupg' --batch --no-tty --yes \
          "''${r[@]}" --trust-model always \
          --compress-algo none \
          -v -e "$dump"
        rm -f "$dump"
      ''}
    else
      echo "$aim exists. Not dumping." >&2
    fi
    ${optionalString (cfg.s3uri != null) ''
      remote="${removeSuffix "/" cfg.s3uri}/$DATE/$aim"
      if ! ${s3cmd} ls "$remote" | ${pkgs.gnugrep}/bin/grep -qF "/$aim"; then
        ${s3cmd} put "$aim" "$remote"
      else
        echo "$remote exists. Not uploading." >&2
      fi
    ''}
  '';

  mkJobs = name: server: pkgs.writeBashScript "mkjobs-${name}" ''
    set -euo pipefail
    mkdir -p '${privateDir}/jobs/${name}'
    for db in $(${mysql} --defaults-file=${defaultsFile name server} -N < ${showDatabases name server} | shuf)
    do
      ln -svf ${job name server} "${privateDir}/jobs/${name}/$db"
    done
  '';

  preStart = ''
    mkdir --mode=0750 -p '${cfg.dumpDir}'
    chown -R ${cfg.user}:${cfg.user} '${cfg.dumpDir}'
    chmod -R u=rwX,g=rX,o= ${cfg.dumpDir}

    rm -rf '${privateDir}'
    mkdir --mode=0700 -p '${privateDir}'
    chown ${cfg.user}:${cfg.user} '${privateDir}'
  '';

  main = pkgs.writeBashScriptBin "mysqlbackup" ''
    set -euo pipefail
    umask 0027
    DATE=$(date --iso-8601)
    HOME='${privateDir}'
    PARALLEL_SHELL=${pkgs.bash}/bin/bash
    export DATE
    export HOME
    export PARALLEL_SHELL

    clean() {
      ${pkgs.findutils}/bin/find '${cfg.dumpDir}' -type f -name '*.tmp' -delete || true
    }

    listSets() {
      ${pkgs.findutils}/bin/find '${cfg.dumpDir}' \
        -maxdepth 1 -mindepth 1 -type d -name '????-??-??' \
        | sort -V
    }

    enoughStorage() {
      local n
      local used
      local total
      local avg
      local p
      n=$(listSets | wc -l)
      used=$(du -x -s --block-size=1M '${cfg.dumpDir}' | cut -f1)
      total=$(df --output=size --block-size=1M '${cfg.dumpDir}' | tail -n 1)
      if [ "$n" -eq 0 ]; then
        echo "no sets" >&2
        return 0
      fi

      avg=$(( used / n ))
      p=$(( 100 * avg * (n + 1) / total ))
      printf "estimated storage: %d of %d MiB (%d%%, max ${toString cfg.storage}%%)\n" \
             "$((used + avg))" "$total" "$p" >&2
      if [ "$p" -le ${toString cfg.storage} ]; then
        return 0
      else
        return 1
      fi
    }

    clean

    listSets | head -n -${toString (cfg.slots - 1)} \
      | ${pkgs.findutils}/bin/xargs --no-run-if-empty rm -rfv \
      || true

    while ! enoughStorage; do
      listSets | head -n 1 \
      | ${pkgs.findutils}/bin/xargs --no-run-if-empty rm -rfv \
      || true
    done

    mkdir -p "${cfg.dumpDir}/$DATE"
    mkdir -p '${privateDir}/cnf'
    mkdir -p '${privateDir}/jobs'

    ${optionalString (gpgPubKeys != []) ''
      # shellcheck disable=SC2174
      mkdir --mode=0700 -p '${privateDir}/gnupg'
      ln -sf ${pubring} '${privateDir}/gnupg/pubring.kbx'
    ''}

    ${concatStringsSep "\n" (
      mapAttrsToList (n: s: ''
        printf '[client]\npassword=' > '${privateDir}/cnf/${n}'
        cat '${s.connection.password-file}' >> '${privateDir}/cnf/${n}'
      '') (filterAttrs (_: s: s.connection.password-file != null) cfg.servers)
    )}

    {
    cat <<'LIST'
    ${concatStringsSep "\n" (mapAttrsToList (mkJobs) cfg.servers)}
    LIST
    } | ${pkgs.parallel}/bin/parallel \
      --halt-on-error 0 \
      --jobs 100% \
      --line-buffer \
      --no-notice \
      --no-run-if-empty \
      --retries 2 \
      --shuf \
      --tagstr '* {}:' \
      --timeout ${toString (10 * 60)} \
      || true

    failed=0
    log="${cfg.dumpDir}/$DATE/joblog.txt"

    {
      cd '${privateDir}/jobs' && find -type l -printf '%P\n';
    } | ${pkgs.parallel}/bin/parallel \
      --halt-on-error 0 \
      --joblog "$log" \
      --jobs '${toString cfg.jobs}' \
      --line-buffer \
      --no-notice \
      --no-run-if-empty \
      --retries 2 \
      --tagstr '* {}:' \
      --timeout ${toString (6 * 60 * 60)} \
      '${privateDir}/jobs/{}' || failed=$?

    cat "$log"
    clean

    du -sh "${cfg.dumpDir}/$DATE" || true
    exit "$failed"
  '';

in {
  options.nixsap.apps.mysqlbackup = {
    user = mkOption {
      description = "User to run as";
      default = "mysqlbackup";
      type = str;
    };

    startAt = mkOption {
      description = "Time to start (systemd format)";
      default = "02:00";
      type = str;
    };

    dumpDir = mkOption {
      description = "Directory to save dumps in";
      default = "/mysqlbackup";
      type = path;
    };

    slots = mkOption {
      description = ''
        How many backup sets should be kept locally.
        However, old sets will be removed anyway if storage
        constraints apply.
        '';
      default = 60;
      type = int;
    };

    storage = mkOption {
      description = ''
        Percent of storage backups can occupy.
      '';
      default = 75;
      type = int;
    };

    encrypt = mkOption {
      description = "Public GPG key(s) for encrypting the dumps";
      default = [ ];
      type = either path (listOf path);
    };

    servers = mkOption {
      default = {};
      type = attrsOf server;
    };

    jobs = mkOption {
      description = ''
        Number of jobs (mysqldump) to run in parallel.
        In the format of GNU Parallel, e. g. "100%", -1. +3, 7, etc.
      '';
      default = "50%";
      type = either int str;
    };

    s3cfg = mkOption {
      description = "s3cmd config file (secret)";
      type = nullOr path;
      default = null;
    };

    s3uri = mkOption {
      description = "S3 bucket URI with prefix in s3cmd format";
      type = nullOr str;
      default = null;
      example = "s3://backups/nightly";
    };
  };

  config = mkIf (cfg.servers != {}) {
    nixsap.system.users.daemons = [ cfg.user ];
    nixsap.deployment.keyrings.${cfg.user} = keys;
    systemd.services.mysqlbackup = {
      description = "MySQL backup";
      after = [ "local-fs.target" "keys.target" "network.target" ];
      wants = [ "keys.target" ];
      startAt = cfg.startAt;
      inherit preStart;
      serviceConfig = {
        ExecStart = "${main}/bin/mysqlbackup";
        User = cfg.user;
        PermissionsStartOnly = true;
      };
    };
  };
}
