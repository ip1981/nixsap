{ config, pkgs, lib, ... }:
let

  inherit (builtins)
    elem isBool isList isString toString ;
  inherit (lib)
    concatMapStringsSep concatStringsSep filter filterAttrs
    findFirst flatten hasPrefix mapAttrsToList mkIf
    mkOption optionalString removeSuffix ;
  inherit (lib.types)
    bool either enum int listOf nullOr path str submodule ;

  cfg = config.nixsap.apps.pgbackup;
  privateDir = "/run/pgbackup";

  s3cmd = "${pkgs.s3cmd}/bin/s3cmd ${optionalString (cfg.s3cfg != null) "-c '${cfg.s3cfg}'"}";

  gpgPubKeys = flatten [ cfg.encrypt ];
  gpg = "${pkgs.gpg}/bin/gpg2";
  pubring = pkgs.runCommand "pubring.gpg" {} ''
    ${gpg} --homedir . --import ${toString gpgPubKeys}
    cp pubring.gpg $out
  '';

  default = d: t: mkOption { type = t; default = d; };
  optional = type: mkOption { type = nullOr type; default = null; };
  sub = options: submodule { inherit options; } ;
  concatMapAttrsSep = s: f: attrs: concatStringsSep s (mapAttrsToList f attrs);

  command = sub
    {
      blobs                   = optional bool;
      clean                   = optional bool;
      compress                = default 9 int;
      create                  = optional bool;
      data-only               = optional bool;
      dbname                  = optional str;
      exclude-schema          = optional (either str (listOf str));
      exclude-table           = optional (either str (listOf str));
      exclude-table-data      = optional (either str (listOf str));
      format                  = default "plain" (enum ["plain" "custom" "directory" "tar"]);
      host                    = optional str;
      if-exists               = optional bool;
      inserts                 = optional bool;
      jobs                    = default 2 int;
      oids                    = optional bool;
      port                    = optional int;
      quote-all-identifiers   = optional bool;
      role                    = optional str;
      schema                  = optional (either str (listOf str));
      schema-only             = optional bool;
      serializable-deferrable = optional bool;
      table                   = optional (either str (listOf str));
      username                = optional str;
    };

  job = o:
    let
      dbname = findFirst (n: n != null) cfg.user [ o.dbname o.username ];
      name = "pg_dump"
           + optionalString (o.host != null && o.host != "localhost") "-${o.host}"
           + optionalString (o.port != null) "-${toString o.port}"
           + "-${dbname}"
           + "-${o.format}";

      args = filterAttrs (n: v:
          v != null && n != "_module"
          && (n == "host"     -> v != "localhost")
          && (n == "jobs"     -> o.format == "directory")
             # XXX will use pigz for others:
          && (n == "compress" -> elem o.format ["directory" "custom"])
        ) o;

      mkArg = k: v:
       if isBool v then (optionalString v "--${k}")
       else if isList v then concatMapStringsSep " " (i: "--${k}='${i}'") v
       else if isString v then "--${k}='${v}'"
       else "--${k}=${toString v}" ;

      # XXX: Use the latest pg_dump:
      pg_dump = pkgs.writeBashScript name ''
        ${optionalString (cfg.pgpass != null) "export PGPASSFILE='${cfg.pgpass}'"}
        exec ${pkgs.postgresql95}/bin/pg_dump \
          ${concatMapAttrsSep " " mkArg args} \
          "$@"
      '';

      compExt = optionalString (o.compress > 0) ".gz";
      compPipe = optionalString (o.compress > 0)
        "| ${pkgs.pigz}/bin/pigz -${toString o.compress} -p${toString o.jobs}";
      suff = if o.format == "directory" then "dir.tar"
        else if o.format == "tar" then "tar${compExt}"
        else if o.format == "custom" then "pgdump"
        else "pgsql${compExt}" ;

    in pkgs.writeBashScript "${name}-job" ''
      set -euo pipefail
      cd "${cfg.dumpDir}/$DATE"
      ${
        if o.host != null && o.host != "localhost" then
          "host='${o.host}'"
        else
          "host=$(${pkgs.nettools}/bin/hostname -f)"
      }

      dump="${dbname}@''${host}${optionalString (o.port != null) ":${toString o.port}"},$DATE.${suff}"
      ${
        if (gpgPubKeys != []) then
          ''aim="$dump.gpg"''
        else
          ''aim="$dump"''
      }

      if ! [ -r "$aim" ]; then
        ${
          if o.format == "directory" then ''
            rm -rf "$dump.tmp"
            ${pg_dump} -f "$dump.tmp"
            ${pkgs.gnutar}/bin/tar \
              --owner=0 --group=0 --mode u=rwX,g=rX,o= \
              --remove-files --transform 's,\.dir\.tar\.tmp,,' -c "$dump.tmp" -f "$dump"
            rm -rf "$dump.tmp"
          '' else if o.format == "custom" then ''
            ${pg_dump} -f "$dump.tmp"
            mv "$dump".tmp "$dump"
          '' else ''
            ${pg_dump} ${compPipe} > "$dump.tmp"
            mv "$dump".tmp "$dump"
          ''
        }

        ${optionalString (gpgPubKeys != []) ''
          recipient=( $(${gpg} --homedir '${privateDir}/gnupg' -k --with-colons --fast-list-mode | \
            ${pkgs.gawk}/bin/awk -F: '/^pub/{print $5}') )
          r=( "''${recipient[@]/#/-r}" )
          ${gpg} --homedir '${privateDir}/gnupg' --batch --no-tty --yes \
            "''${r[@]}" --trust-model always \
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

  preStart = ''
    mkdir --mode=0750 -p '${cfg.dumpDir}'
    chown -R ${cfg.user}:${cfg.user} '${cfg.dumpDir}'
    chmod -R u=rwX,g=rX,o= ${cfg.dumpDir}

    rm -rf '${privateDir}'
    mkdir --mode=0700 -p '${privateDir}'
    chown ${cfg.user}:${cfg.user} '${privateDir}'
  '';

  main = pkgs.writeBashScriptBin "pgbackup" ''
    set -euo pipefail
    umask 0027
    DATE=$(date --iso-8601)
    HOME='${privateDir}'
    PARALLEL_SHELL=${pkgs.bash}/bin/bash
    export DATE
    export HOME
    export PARALLEL_SHELL

    clean() {
      ${pkgs.findutils}/bin/find '${cfg.dumpDir}' \
        -name '*.tmp' -exec rm -rf {} + || true
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

    ${optionalString (gpgPubKeys != []) ''
      # shellcheck disable=SC2174
      mkdir --mode=0700 -p '${privateDir}/gnupg'
      ln -sf ${pubring} '${privateDir}/gnupg/pubring.gpg'
    ''}

    failed=0
    log="${cfg.dumpDir}/$DATE/joblog.txt"

    # shellcheck disable=SC2016
    ${pkgs.parallel}/bin/parallel \
      --halt-on-error 0 \
      --joblog "$log" \
      --jobs 50% \
      --line-buffer \
      --no-notice \
      --no-run-if-empty \
      --retries 2 \
      --rpl '{nixbase} s:^/nix/store/[^-]+-pg_dump-(.+)-job$:$1:' \
      --tagstr '* {nixbase}:' \
      --timeout ${toString (6 * 60 * 60)} ::: \
      ${concatMapStringsSep " " job cfg.pg_dump} \
      || failed=$?

    cat "$log"
    clean

    du -sh "${cfg.dumpDir}/$DATE" || true
    exit "$failed"
  '';

  keys = filter (f: f != null && hasPrefix "/run/keys/" f) ( [cfg.pgpass cfg.s3cfg] );

in {
  options.nixsap.apps.pgbackup = {
    user = mkOption {
      description = "User to run as";
      default = "pgbackup";
      type = str;
    };

    dumpDir = mkOption {
      description = "Directory to save dumps in";
      default = "/pgbackup";
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

    pg_dump = mkOption {
      description = "pg_dump commands";
      default = [];
      type = listOf command;
    };

    pgpass = mkOption {
      description = "The Password File (secret)";
      type = nullOr path;
      default = null;
    };
  };

  config = mkIf (cfg.pg_dump != []) {
    nixsap.system.users.daemons = [ cfg.user ];
    nixsap.deployment.keyrings.${cfg.user} = keys;
    systemd.services.pgbackup = {
      description = "PostgreSQL backup";
      after = [ "local-fs.target" "keys.target" "network.target" ];
      wants = [ "keys.target" ];
      startAt = "02:00";
      inherit preStart;
      serviceConfig = {
        ExecStart = "${main}/bin/pgbackup";
        User = cfg.user;
        PermissionsStartOnly = true;
      };
    };
  };
}
