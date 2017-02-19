{ config, lib, pkgs, ... }:

let

  inherit (lib)
    concatMapStringsSep concatStrings filterAttrs foldAttrs mapAttrs'
    mapAttrsToList mkOption optionalString ;

  inherit (lib.types)
    attrsOf submodule ;

  explicit = filterAttrs (n: v: n != "_module" && v != null);
  instances = explicit config.nixsap.apps.gnupg;

  keyrings =
    let
      ik = mapAttrsToList (_: i: {
        "${i.user}" = i.secretKeys ++ mapAttrsToList (_: f: f) i.passphrase;
      }) instances;
    in foldAttrs (l: r: l ++ r) [] ik;


  mkService = name: cfg:
    let

      pubring = pkgs.runCommand "gnupg-${name}-pubring.kbx" {} ''
        ${cfg.package}/bin/gpg2 \
          --homedir . \
          --import \
          ${concatMapStringsSep " " (k: "'${k}'") cfg.publicKeys}
        cp pubring.kbx $out
      '';

      start = pkgs.writeBashScriptBin "gnupg-${name}-start" ''
        set -euo pipefail
        umask 0077

        cat <<'CONF' > '${cfg.home}/gpg.conf'
        batch
        no-tty
        trust-model always
        yes
        CONF

        # XXX forking.
        # XXX is 30 years enough?
        ${cfg.package}/bin/gpg-agent \
          --homedir '${cfg.home}' \
          --allow-preset-passphrase \
          --batch \
          --max-cache-ttl 999999999 \
          --quiet \
          --daemon

        ${optionalString (cfg.publicKeys != []) ''
          ln -sf '${pubring}' '${cfg.home}/pubring.kbx'
        ''}

        export GNUPGHOME='${cfg.home}'

        ${optionalString (cfg.secretKeys != []) ''
          ${cfg.package}/bin/gpg2 --import \
            ${concatMapStringsSep " " (k: "'${k}'") cfg.secretKeys}
        ''}


        ${concatStrings (mapAttrsToList (cacheid: f: ''
            head -n 1 '${f}' \
            | ${cfg.package}/libexec/gpg-preset-passphrase \
              --verbose --preset '${cacheid}'
          '') cfg.passphrase)
        }


      '';

    in {
      name = "gnupg-${name}";
      value = {
        description = "gnupg (${name})";
        wantedBy = [ "multi-user.target" ];
        after = [ "keys.target" "local-fs.target" ];
        preStart = ''
          mkdir -p -- '${cfg.home}'
          rm -rf -- '${cfg.home}/'*
          chmod u=rwX,g=,o= -- '${cfg.home}'
          chown '${cfg.user}.${cfg.user}' -- '${cfg.home}'
        '';

        serviceConfig = {
          ExecStart = "${start}/bin/gnupg-${name}-start";
          PermissionsStartOnly = true;
          Restart = "always";
          Type = "forking";
          User = cfg.user;
        };
      };
    };

in {

  options = {
    nixsap.apps.gnupg = mkOption {
      description = "GnuPG instances";
      default = {};
      type = attrsOf (submodule (import ./instance.nix pkgs));
    };
  };

  config = {
    nixsap.deployment.keyrings = keyrings;
    systemd.services = mapAttrs' mkService instances;
  };

}

