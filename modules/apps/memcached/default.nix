{ config, lib, pkgs, ... }:

let

  inherit (builtins)
    elem filter isBool isList ;

  inherit (lib)
    concatMapStringsSep concatStringsSep filterAttrs flatten foldAttrs foldl
    mapAttrsToList mkOption optionalString ;

  inherit (lib.types)
    attrsOf submodule ;

  concatMapAttrsSep = s: f: attrs: concatStringsSep s (mapAttrsToList f attrs);

  explicit = filterAttrs (n: v: n != "_module" && v != null);
  instances = explicit config.nixsap.apps.memcached;
  users = mapAttrsToList (_: i: i.user) instances;


  mkService = name: cfg:
    let

      show = n: v:
        if isList v then map (s: "-${n} '${toString s}'") v
        else if isBool v then (optionalString v "-${n}")
        else "-${n} '${toString v}'";

      args = flatten (mapAttrsToList show (explicit cfg.args));

      start = pkgs.writeBashScriptBin "memcached-${name}-start" ''
        set -euo pipefail
        umask 0027

        exec ${cfg.package}/bin/memcached \
        ${concatStringsSep " \\\n" args}
      '';

    in {
      "memcached-${name}" = {
        description = "memcached (${name})";
        wantedBy = [ "multi-user.target" ];
        after = [ "keys.target" "network.target" "local-fs.target" ];
        serviceConfig = {
          ExecStart = "${start}/bin/memcached-${name}-start";
          Restart = "always";
          User = cfg.user;
        };
      };
    };

in {

  options.nixsap.apps.memcached = mkOption {
    description = "Memcached instances";
    default = {};
    type = attrsOf (submodule (import ./instance.nix pkgs));
  };

  config = {
    systemd.services = foldl (a: b: a//b) {} (mapAttrsToList mkService instances);
    nixsap.system.users.daemons = users;
  };

}

