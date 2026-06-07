{ config, lib, pkgs, ... }:

let

  inherit (builtins)
    attrNames baseNameOf head map match
    ;
  inherit (lib)
    filter flip foldl genAttrs hasPrefix mapAttrs' mapAttrsToList mkOption
    nameValuePair optionalAttrs unique
    ;
  inherit (lib.types)
    attrsOf either externalPath int listOf nullOr package path str submodule
    ;

  cfg = config.nixsap.deployment;

  emptyKey = pkgs.writeText "empty" "";
  getKeySource = key:
    let
      m = match "^(.+)@[^@]+$" key;
      s = if m != null then head m else key;
    in if cfg.secrets != null
      then cfg.secrets + "/${s}"
      else emptyKey;

in {
  options.nixsap.deployment = {
    secrets = mkOption {
      description = ''
        Directory with the secrets on the build machine. If not specified,
        each key in the keyrings will be an empty file.
        '';
      type = nullOr externalPath;
      default = null;
      example = "<secrets>";
    };

    keyStore = mkOption {
      description = ''
        Directory with the keys on the target machine.
        This directory will be created, its permissions changed to
        ``0750`` and ownership to ``root:keys``.
        '';
      type = externalPath;
      default = "/run/keys";
      example = "/root/keys";
    };

    keyrings = mkOption {
      type = attrsOf (listOf (nullOr path));
      description = ''
        Binds keys to a user. It's possible to share the same key between
        multiple users, of course by different names: "/run/keys/foo"
        and "/run/keys/foo@bar" will use the same secret file "foo". Any
        file whose path does not start with `nixsap.deployment.keyStore` is
        deliberately ignored. E. i. you can pass any file names, and nixsap
        will pick up keys for you. For convenience, it is allowed to pass
        null values, which are filtered-out as well.
      '';
      default = {};
      example = { mysqlbackup = [ "/run/keys/s3cmd.cfg" ];
                  pgbackup = [ "/run/keys/s3cmd.cfg@pgbackup" ];
                };
    };

    keys = mkOption {
      default = {};
      description = ''
        The set of keys to be deployed to the machine.  Each attribute maps
        a key name to a file that can be accessed as ``keyStore``/``name``.
        A key is a file which cannot be in Nix store for security reasons,
        e. g. it contains a password, a SSH private key, etc.
        Each key also gets a systemd service ``<name>-key.service``
        which is active while the key is present and inactive while the key
        is absent.
      '';

      type = attrsOf (submodule ({name, config, ...}: {
        options = {
          source = mkOption {
            description = ''
              Local file contaning the key. The contents of this file will put on the machine
              in a file maching the key's name.
              '';
            type = path;
          };
          uid = mkOption {
            default = 0;
            type = int;
            description = ''
              The user id that will be set for the key file.
            '';
          };
          gid = mkOption {
            default = 0;
            type = int;
            description = ''
              The group id that will be set for the key file.
            '';
          };
          mode = mkOption {
            default = 400;
            example = "0640";
            type = int;
            description = ''
              The access mode that will be set for the key file.
              Should be in a numeric form accepted by ``chmod(1)``.
            '';
          };
        };
      }));
    };

    send-keys-sftp = mkOption {
      type = package;
      description = ''
        Derive this file with `nix-build '<nixpkgs/nixos>' -A config.nixsap.deployment.send-keys-sftp ... --no-out-link`
        and feed it to the ``sftp(1)`` to upload the secrets (the keys) to the machine.
      '';
      readOnly = true;
      default =
        let
          key-store-dir = pkgs.runCommand "key-store-dir" {} "mkdir -p $out/'${cfg.keyStore}'";
          key-cmds = lib.concatStringsSep "\n" (flip mapAttrsToList cfg.keys (name: key: ''
            put '${key.source}' '${name}.tmp'
            chmod ${toString key.mode} '${name}.tmp'
            chown ${toString key.uid} '${name}.tmp'
            chgrp ${toString key.gid} '${name}.tmp'
            rename '${name}.tmp' '${name}'
          ''));
        in pkgs.writeText "send-keys-sftp" (
          if cfg.keys != {} then ''
            cd /
            lcd '${key-store-dir}'
            put -pR *

            chown ${toString config.users.users.root.uid} '${cfg.keyStore}'
            chgrp ${toString config.users.groups.keys.gid} '${cfg.keyStore}'
            chmod 0750 '${cfg.keyStore}'

            cd '${cfg.keyStore}'

            ${key-cmds}
            bye
          '' else ''
            bye
          ''
        );
    };
  };

  config = {
    nixsap.deployment.keys = foldl (a: b: a//b) {} (
      mapAttrsToList (user: keys:
        let realkeys = unique (filter (n: n != null && hasPrefix cfg.keyStore n) keys);
        in genAttrs (map baseNameOf realkeys)
                 (key: { source = getKeySource key;
                         uid = config.users.users.${user}.uid;
                       })
      ) cfg.keyrings
    );

    users.users = genAttrs (attrNames cfg.keyrings) (
      user: optionalAttrs (user != "root") { extraGroups = [ "keys" ]; }
    );

    systemd.services =
      flip mapAttrs' cfg.keys (name: key:
        nameValuePair "${name}-key" {
          enable = true;
          serviceConfig = {
            TimeoutStartSec = "infinity";
            Restart = "always";
            RestartSec = "100ms";
            ExecStartPre = "${pkgs.wait4file} '${cfg.keyStore}/${name}'";
            ExecStart = "${pkgs.hangonfile} '${cfg.keyStore}/${name}'";
          };
        }
      );

  };
}
