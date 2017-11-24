{ config, lib, pkgs, ... }:

let

  inherit (builtins)
    attrNames isBool isString replaceStrings ;

  inherit (lib)
    concatMapStringsSep concatStringsSep escape filterAttrs foldAttrs foldl
    hasPrefix mapAttrs mapAttrsToList mkOption nameValuePair optionalString
    unique ;

  inherit (lib.types)
    attrsOf submodule ;

  explicit = filterAttrs (n: v: n != "_module" && v != null);

  instances = explicit config.nixsap.apps.jenkins;
  users = mapAttrsToList (_: i: i.user) instances;

  maybeFile = name: cnt:
    let norm = replaceStrings [" "] ["-"] name;
    in if hasPrefix "/" cnt
       then "${cnt}"
       else pkgs.writeXML norm cnt;

  configFiles = name: cfg: mapAttrs (n: v: maybeFile "jenkins-${name}-${n}" v) cfg.config;
  jobFiles = name: cfg: mapAttrs (n: v: maybeFile "jenkins-${name}-job-${n}.xml" v) cfg.jobs;

  keyrings =
    let
      # This requires read-write mode of evaluation:
      keys = n: i: import (pkgs.xinclude2nix (
           (mapAttrsToList (_: f: f) (configFiles n i))
        ++ (unique (mapAttrsToList (_: f: f) (jobFiles n i)))
        ));
      ik = mapAttrsToList (n: i: { "${i.user}" = keys n i; } ) instances;
    in foldAttrs (l: r: l ++ r) [] ik;

  mkService = name: cfg:
    let

      mkOpt = n: v: if isBool v then (if v then "--${n}" else "")
           else if isString v then "--${n}='${v}'"
           else "--${n}=${toString v}";

      path = ".war.path";
      tmpdir = "${cfg.home}/tmp";

      start = pkgs.writeBashScriptBin "jenkins-${name}" ''
        set -euo pipefail
        umask 0027
        export HOME='${cfg.home}'
        export SHELL='${pkgs.bash}/bin/bash'

        cd '${cfg.home}'

        find . -maxdepth 1 \( \
             -iname '*.xml' \
          -o -iname '*.bak' \
          -o -iname '*.log' \
          -o -iname '*.tmp' \
          -o -iname '*.txt' \
          \) -delete

        ${concatStringsSep "\n" (
          mapAttrsToList (n: p:
          # XXX Jenkins does not support XInclude
          # XXX We use XInclude to include secret files (keys)
          ''
            ${pkgs.libxml2}/bin/xmllint --xinclude --format '${p}' > '${n}'
          '') (configFiles name cfg)
        )}

        if [ -d jobs ]; then
          find jobs -maxdepth 1 -mindepth 1 -type d \
            ${concatMapStringsSep " " (k: "-not -name '${escape [ "[" ] k}'") (attrNames cfg.jobs)} \
            -print0 | xargs -0 --verbose --no-run-if-empty rm -rf
        fi

        ${concatStringsSep "\n" (
          mapAttrsToList (n: p: ''
            mkdir -p -- 'jobs/${n}'
            rm -rf -- 'jobs/${n}/config.xml'
            ${pkgs.libxml2}/bin/xmllint --xinclude --format '${p}' > 'jobs/${n}/config.xml'
          '') (jobFiles name cfg)
        )}

        if [ -f ${path} ]; then
          old=$(cat ${path})
        else
          old=
        fi

        # FIXME: make sure old content is flushed
        if [ '${cfg.war}' != "$old" ]; then
          rm -rf war plugins
          echo '${cfg.war}' > ${path}
        fi

        rm -rf -- '${tmpdir}'
        mkdir -p -- '${tmpdir}'
        exec ${cfg.jre}/bin/java \
          -DJENKINS_HOME='${cfg.home}' \
          -Djava.io.tmpdir='${tmpdir}' \
          -jar '${cfg.war}' \
          ${concatStringsSep " \\\n  " (
            mapAttrsToList mkOpt (explicit cfg.options))}
      '';

    in {
      "jenkins-${name}" = {
        description = "Jenkins (${name}) automation server";
        wantedBy = [ "multi-user.target" ];
        after = [ "keys.target" "network.target" "local-fs.target" ];
        inherit (cfg) path;
        preStart = ''
          mkdir -p -- '${cfg.home}'

          # XXX ignore potentially dangling symlinks
          # XXX like lastStable -> builds/lastStableBuild.
          # XXX chmod/chown fail on them
          find '${cfg.home}' -not -type l \( \
              -not -user '${cfg.user}' \
          -or -not -group '${cfg.user}' \
          -or \( -type d -not -perm -u=wrx,g=rx \) \
          -or \( -type f -not -perm -u=rw,g=r \) \
          \) \
          -exec chown -c -- '${cfg.user}:${cfg.user}' {} + \
          -exec chmod -c -- u=rwX,g=rX,o= {} +

        '';
        serviceConfig = {
          ExecStart = "${start}/bin/jenkins-${name}";
          KillMode = "mixed";
          PermissionsStartOnly = true;
          Restart = "always";
          TimeoutSec = 0;
          User = cfg.user;
        };
      };
    };

in {

  options.nixsap.apps.jenkins = mkOption {
    description = "Jenkins instances";
    default = {};
    type = attrsOf (submodule (import ./instance.nix pkgs));
  };

  config = {
    systemd.services = foldl (a: b: a//b) {} (mapAttrsToList mkService instances);
    nixsap.deployment.keyrings = keyrings;
    nixsap.system.users.daemons = users;
  };

}
