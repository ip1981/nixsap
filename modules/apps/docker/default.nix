{ config, pkgs, lib, ... }:

let

  inherit (builtins) toJSON;

  inherit (lib)
    filterAttrs foldl mapAttrsToList mkOption optional
    ;

  inherit (lib.types) attrsOf submodule;

  explicit = filterAttrs (n: v: n != "_module" && v != null);

  instances = explicit config.nixsap.apps.docker;

  groups = mapAttrsToList (_: i: i.daemon.group) instances;
  clis = mapAttrsToList (_: i: i.docker-cli) instances;

  mkService = name: opts:
    let
      config-file = pkgs.runCommand "dockerd-${name}.json" {} ''
        cat <<'EOF' | ${pkgs.jq}/bin/jq . > $out
        ${toJSON (explicit (opts.daemon))}
        EOF
      '';
    in {
      "docker-${name}" = {
        description = "Docker daemon (${name})";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        path = [ pkgs.kmod ] ++ (optional (opts.daemon.storage-driver == "zfs") pkgs.zfs);
        preStart = ''
          mkdir -p -- '${opts.daemon.data-root}'
          rm -rf --  '${opts.daemon.exec-root}'
          mkdir -p --  '${opts.daemon.exec-root}'

          chown -c -- 'root:root' '${opts.daemon.data-root}'
          chmod -c -- u=rwX,g=rX,o= '${opts.daemon.data-root}'
        '';
        serviceConfig = {
          ExecStart = "${opts.package}/bin/dockerd --config-file ${config-file}";
          ExecReload = "${pkgs.procps}/bin/kill -s HUP $MAINPID";
        };
      };
    };

in {

  options.nixsap.apps.docker = mkOption {
    description = "Instances of Docker";
    type = attrsOf (submodule (import ./instance.nix pkgs));
    default = {};
  };

  config = {
    systemd.services = foldl (a: b: a//b) {} (mapAttrsToList mkService instances);
    nixsap.system.groups = groups;
    environment.systemPackages = clis;
  };

}

