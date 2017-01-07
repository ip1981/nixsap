{ config, lib, pkgs, ... }:

let

  inherit (builtins)
    isList isString replaceStrings ;

  inherit (lib)
    concatMapStringsSep concatStringsSep filter filterAttrs flatten foldAttrs
    foldl hasPrefix imap mapAttrsToList mkOption ;

  inherit (lib.types)
    attrsOf path str submodule ;

  explicit = filterAttrs (n: v: n != "_module" && v != null);
  instances = explicit config.nixsap.apps.openldap;
  users = mapAttrsToList (_: i: i.user) instances;

  keyrings =
    let
      keyFiles = i: filter (hasPrefix config.nixsap.deployment.keyStore) i.apply;
      ik = mapAttrsToList (_: i: {
        "${i.user}" = [i."cn=config".olcTLSCertificateKeyFile] ++ keyFiles i;
      } ) instances;
    in foldAttrs (l: r: l ++ r) [] ik;

  mkService = name: cfg:
    let

      uid = config.users.users.${cfg.user}.uid;
      gid = config.users.groups.${cfg.user}.gid;

      show = n: v:
        if isList v then map (s: "${n}: ${toString s}") v
        else "${n}: ${toString v}";

      olc = let olcXX = filterAttrs (n: _: hasPrefix "olc" n) (explicit cfg."cn=config");
            in flatten (mapAttrsToList show olcXX);

      configInit = pkgs.writeText "openldap-${name}-cn=config.ldif" ''
        dn: cn=config
        objectClass: olcGlobal
        cn: config
        ${concatStringsSep "\n" olc}

        dn: cn=schema,cn=config
        objectClass: olcSchemaConfig
        cn: schema

        # XXX: access rule of this DB are appended to each other DB, except {0}config (???).
        dn: olcDatabase={-1}frontend,cn=config
        objectClass: olcDatabaseConfig
        objectClass: olcFrontendConfig
        olcDatabase: {-1}frontend
        olcAccess: {0}to * by dn.exact=gidNumber=${toString gid}+uidNumber=${toString uid},cn=peercred,cn=external,cn=auth manage by * break

        dn: olcDatabase={0}config,cn=config
        objectClass: olcDatabaseConfig
        olcDatabase: {0}config
        olcReadOnly: TRUE
        olcAccess: {0}to * by dn.exact=gidNumber=${toString gid}+uidNumber=${toString uid},cn=peercred,cn=external,cn=auth read by * break
        olcAccess: {1}to * by * none

        ${cfg."cn=config".ldif}
      '';

      slapdDir = "${cfg.home}/slapd.d";

      socket = replaceStrings
              [ " " "/"   ]
              [ "+" "%2F" ]
              "${cfg.home}/${name}.sock";

      # XXX: OpenLDAP starts as root for privileged ports. Capabilities set by systemd aren't reliable
      # XXX: See for example https://github.com/systemd/systemd/issues/5000
      start = pkgs.writeBashScriptBin "openldap-${name}" ''
        set -euo pipefail

        rm -rf -- '${slapdDir}'
        mkdir -p '${slapdDir}'

        # XXX: All `olcDbDirectory` must exist before slapd or slapadd run
        # XXX: until http://www.openldap.org/lists/openldap-devel/200904/msg00015.html
        while IFS= read -r d
        do
          if [[ "$d" == '${cfg.home}/'* ]]; then
            if [ ! -d "$d" ]; then
              mkdir -p -- "$d"
              chmod -R u=rwX,g=rX,o= -- "$d"
              chown -R '${cfg.user}:${cfg.user}' -- "$d"
            fi
          else
            echo "Path '$d' is not under '${cfg.home}'" >&2
            exit 1
          fi
        done < <(${pkgs.gnused}/bin/sed -rn '/^olcDbDirectory:/ s!^olcDbDirectory: *(.+) *$!\1!p' '${configInit}')

        echo '>>>>> importing ${configInit} ...'
        ${cfg.package}/bin/slapadd -n 0 -v -F '${slapdDir}' \
          ${concatMapStringsSep " " (o: "-d ${o}") cfg.debugLevel} \
          -l ${configInit}
        chmod -R u=rX,g=rX,o= '${slapdDir}'
        chown -R '${cfg.user}:${cfg.user}' '${slapdDir}'
        echo '<<<<< imported ${configInit}'

        exec ${cfg.package}/libexec/slapd \
          -n 'openldap-${name}' \
          -u '${cfg.user}' \
          -g '${cfg.user}' \
          -h 'ldapi://${socket} ${cfg.urlList}' \
          ${concatMapStringsSep " " (o: "-d ${o}") cfg.debugLevel} \
          -F '${slapdDir}'
      '';


      ldifs = imap (i: f:
          if hasPrefix "/" f then "'${f}'"
          else pkgs.writeText "openldap-${name}.${toString i}.ldif" f
        ) cfg.apply;


      apply = pkgs.writeBashScriptBin "openldap-${name}-apply" ''
        set -euo pipefail

        while ! ${cfg.package}/bin/ldapsearch \
          -LLL -Y EXTERNAL \
          -H 'ldapi://${socket}' \
          -b 'olcDatabase={0}config,cn=config' dn \
          | ${pkgs.gnugrep}/bin/grep -qF 'olcDatabase={0}config,cn=config'
        do
          sleep 1s
        done

        exec ${pkgs.ldapply}/bin/ldapply \
          -H 'ldapi://${socket}' \
          ${toString ldifs}
      '';

    in {
      "openldap-${name}" = {
        description = "OpenLDAP server (${name})";
        wantedBy = [ "multi-user.target" ];
        after = [ "keys.target" "network.target" "local-fs.target" ];
        preStart = ''
          mkdir -p -- '${cfg.home}'
          find '${cfg.home}' -not -type l \( \
                -not -user '${cfg.user}' \
            -or -not -group '${cfg.user}' \
            -or \( -type d -not -perm -u=wrx,g=rx \) \
            -or \( -type f -not -perm -u=rw,g=r \) \
            \) \
            -exec chown -c -- '${cfg.user}:${cfg.user}' {} + \
            -exec chmod -c -- u=rwX,g=rX,o= {} +
        '';

        unitConfig = {
          # XXX OpenLDAP can be running long before fail:
          StartLimitBurst = 3;
          StartLimitIntervalSec = 300;
        };

        serviceConfig = {
          ExecStart = "${start}/bin/openldap-${name}";
          Restart = "always";
          TimeoutSec = 60;
        };
      };

      "openldap-${name}-apply" = {
        description = "OpenLDAP server (${name}) data update";
        wantedBy = [ "multi-user.target" ];
        after = [ "openldap-${name}.service" ];
        serviceConfig = {
          ExecStart = "${apply}/bin/openldap-${name}-apply";
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutSec = 60;
          User = cfg.user;
        };
      };
    };

in {

  options.nixsap.apps.openldap = mkOption {
    description = "OpenLDAP instances";
    default = {};
    type = attrsOf (submodule (import ./instance.nix pkgs));
  };

  config = {
    nixsap.deployment.keyrings = keyrings;
    nixsap.system.users.daemons = users;
    systemd.services = foldl (a: b: a//b) {} (mapAttrsToList mkService instances);
  };

}
