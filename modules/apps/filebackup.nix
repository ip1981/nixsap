{ config, pkgs, lib, ... }:
let

  inherit (builtins)
    isBool isList isString toString ;
  inherit (lib)
    concatMapStringsSep concatStringsSep filter filterAttrs
    flatten hasPrefix mapAttrsToList mkIf
    mkOption optionalString removeSuffix ;
  inherit (lib.types)
    attrsOf bool either enum int listOf nullOr path str submodule ;

  cfg = config.nixsap.apps.filebackup;
  privateDir = "/run/filebackup";

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
  mandatory = type: mkOption { inherit type; };
  concatMapAttrsSep = s: f: attrs: concatStringsSep s (mapAttrsToList f attrs);

  command = sub
    {
      absolute-names      = optional bool;
      exclude             = optional (either str (listOf str));
      exclude-from        = optional path;
      exclude-vcs         = optional bool;
      exclude-vcs-ignores = optional bool;
      group               = optional str;
      ignore-case         = optional bool;
      mode                = optional str;
      owner               = optional str;
      path                = mandatory (either path (listOf path));
    };

  job = name: o:
    let
      args = filterAttrs (k: v:
          v != null && k != "_module"
          && ( k != "path" )
        ) o;

      mkArg = k: v:
       if isBool v then (optionalString v "--${k}")
       else if isList v then concatMapStringsSep " " (i: "--${k}='${i}'") v
       else if isString v then "--${k}='${v}'"
       else "--${k}=${toString v}" ;

      tar = pkgs.writeBashScript "tar-${name}" ''
        exec ${pkgs.gnutar}/bin/tar -c -f- \
          ${concatMapAttrsSep " " mkArg args} \
          "$@"
      '';

    in pkgs.writeBashScript "tar-${name}-job" ''
      set -euo pipefail
      cd "${cfg.tarballDir}/$DATE"
      host=$(${pkgs.nettools}/bin/hostname -f)

      tarball="${name}@$host,$DATE.tar.xz"
      ${
        if (gpgPubKeys != []) then
          ''aim="$tarball.gpg"''
        else
          ''aim="$tarball"''
      }

      if ! [ -r "$aim" ]; then
        ${tar} ${concatMapStringsSep " " (p: "'${p}'") (flatten [o.path])} \
          | ${pkgs.pxz}/bin/pxz -2 -T2 > "$tarball.tmp"
        mv "$tarball".tmp "$tarball"

        ${optionalString (gpgPubKeys != []) ''
          recipient=( $(${gpg} --homedir '${privateDir}/gnupg' -k --with-colons --fast-list-mode | \
            ${pkgs.gawk}/bin/awk -F: '/^pub/{print $5}') )
          r=( "''${recipient[@]/#/-r}" )
          ${gpg} --homedir '${privateDir}/gnupg' --batch --no-tty --yes \
            "''${r[@]}" --trust-model always \
            --compress-algo none \
            -v -e "$tarball"
          rm -f "$tarball"
        ''}
      else
        echo "$aim exists. Not creating." >&2
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
    mkdir --mode=0750 -p '${cfg.tarballDir}'
    chown -R ${cfg.user}:${cfg.user} '${cfg.tarballDir}'
    chmod -R u=rwX,g=rX,o= ${cfg.tarballDir}

    rm -rf '${privateDir}'
    mkdir --mode=0700 -p '${privateDir}'
    chown ${cfg.user}:${cfg.user} '${privateDir}'
  '';

  main = pkgs.writeBashScriptBin "filebackup" ''
    set -euo pipefail
    umask 0027
    DATE=$(date --iso-8601)
    HOME='${privateDir}'
    PARALLEL_SHELL=${pkgs.bash}/bin/bash
    export DATE
    export HOME
    export PARALLEL_SHELL

    clean() {
      ${pkgs.findutils}/bin/find '${cfg.tarballDir}' \
        -name '*.tmp' -exec rm -rf {} + || true
    }

    listSets() {
      ${pkgs.findutils}/bin/find '${cfg.tarballDir}' \
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
      used=$(du -x -s --block-size=1M '${cfg.tarballDir}' | cut -f1)
      total=$(df --output=size --block-size=1M '${cfg.tarballDir}' | tail -n 1)
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

    mkdir -p "${cfg.tarballDir}/$DATE"

    ${optionalString (gpgPubKeys != []) ''
      # shellcheck disable=SC2174
      mkdir --mode=0700 -p '${privateDir}/gnupg'
      ln -sf ${pubring} '${privateDir}/gnupg/pubring.gpg'
    ''}

    failed=0
    log="${cfg.tarballDir}/$DATE/joblog.txt"

    # shellcheck disable=SC2016
    ${pkgs.parallel}/bin/parallel \
      --halt-on-error 0 \
      --joblog "$log" \
      --jobs 50% \
      --line-buffer \
      --no-notice \
      --no-run-if-empty \
      --retries 2 \
      --rpl '{nixbase} s:^/nix/store/[^-]+-tar-(.+)-job$:$1:' \
      --tagstr '* {nixbase}:' \
      --timeout ${toString (6 * 60 * 60)} ::: \
      ${concatMapAttrsSep " " job cfg.files} \
      || failed=$?

    cat "$log"
    clean

    du -sh "${cfg.tarballDir}/$DATE" || true
    exit "$failed"
  '';

  keys = filter (f: f != null && hasPrefix "/run/keys/" f) ( [cfg.s3cfg] );

in {
  options.nixsap.apps.filebackup = {
    user = mkOption {
      description = "User to run as";
      default = "filebackup";
      type = str;
    };

    tarballDir = mkOption {
      description = "Directory to save tarballs in";
      default = "/filebackup";
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

    files = mkOption {
      description = "tar commands";
      default = {};
      type = attrsOf command;
    };
  };

  config = mkIf (cfg.files != {}) {
    nixsap.system.users.daemons = [ cfg.user ];
    nixsap.deployment.keyrings.${cfg.user} = keys;
    systemd.services.filebackup = {
      description = "Directory backup with tar";
      after = [ "local-fs.target" "keys.target" ];
      wants = [ "keys.target" ];
      startAt = "02:00";
      inherit preStart;
      serviceConfig = {
        ExecStart = "${main}/bin/filebackup";
        User = cfg.user;
        PermissionsStartOnly = true;
      };
    };
  };
}
