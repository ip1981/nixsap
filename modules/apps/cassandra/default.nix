{ config, lib, pkgs, ... }:

let

  inherit (builtins)
    match ;

  inherit (lib)
    concatMapStringsSep concatStringsSep filterAttrs flatten foldAttrs foldl
    mapAttrsToList mkOption ;

  inherit (lib.types)
    attrsOf submodule ;

  explicit = filterAttrs (n: v: n != "_module" && v != null);
  concatMapAttrsSep = s: f: attrs: concatStringsSep s (mapAttrsToList f attrs);

  instances = explicit config.nixsap.apps.cassandra;
  users = mapAttrsToList (_: i: i.user) instances;

  keyrings =
    let
      ik = mapAttrsToList (n: i: { "${i.user}" = []; } ) instances;
    in foldAttrs (l: r: l ++ r) [] ik;

  mkService = name: cfg:
    let

      tmpdir = "${cfg.home}/tmp";
      cp = concatStringsSep ":" cfg.classpath;

      isDir = d: _: match ".*_director(y|ies)$" d != null;
      directories = [ cfg.home ]
        ++ flatten (mapAttrsToList (_: d: d) (filterAttrs isDir (explicit cfg.parameters)));

      directories_sh = concatMapStringsSep " " (d: "'${d}'") directories;


      start = pkgs.writeBashScriptBin "cassandra-${name}" ''
        set -euo pipefail
        umask 0027
        export HOME='${cfg.home}'

        rm   -rf -- '${cfg.jre.properties.java.io.tmpdir}'
        mkdir -p -- '${cfg.jre.properties.java.io.tmpdir}'

        exec ${cfg.jre.package}/bin/java \
        -Dcassandra.config='${cfg.jre.properties.cassandra.config}' \
        -Djava.io.tmpdir='${cfg.jre.properties.java.io.tmpdir}' \
        -Djava.library.path='${concatStringsSep ":" cfg.jre.properties.java.library.path}' \
        -cp '${cp}' \
        org.apache.cassandra.service.CassandraDaemon

      '';

    in {
      "cassandra-${name}" = {
        description = "Cassandra (${name}) distributed NoSQL database";
        wantedBy = [ "multi-user.target" ];
        after = [ "keys.target" "network.target" "local-fs.target" ];
        preStart = ''
          mkdir -p -- ${directories_sh}

          find ${directories_sh} -not -type l \( \
              -not -user '${cfg.user}' \
          -or -not -group '${cfg.user}' \
          -or \( -type d -not -perm -u=wrx,g=rx \) \
          -or \( -type f -not -perm -u=rw,g=r \) \
          \) \
          -exec chown -c -- '${cfg.user}:${cfg.user}' {} + \
          -exec chmod -c -- u=rwX,g=rX,o= {} +

        '';

        unitConfig = {
          # XXX It can be running long before fail:
          StartLimitBurst = 3;
          StartLimitIntervalSec = 60;
        };

        serviceConfig = {
          ExecStart = "${start}/bin/cassandra-${name}";
          KillMode = "mixed";
          PermissionsStartOnly = true;
          Restart = "always";
          TimeoutSec = 0;
          User = cfg.user;
          LimitAS = "infinity";
          LimitMEMLOCK = "infinity";
          LimitNOFILE = 10000;
          LimitNPROC = 32768;
        };
      };
    };

in {

  options.nixsap.apps.cassandra = mkOption {
    description = "Cassandra instances";
    default = {};
    type = attrsOf (submodule (import ./instance.nix pkgs));
  };

  config = {
    systemd.services = foldl (a: b: a//b) {} (mapAttrsToList mkService instances);
    nixsap.deployment.keyrings = keyrings;
    nixsap.system.users.daemons = users;
  };

}
