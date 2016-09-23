{ config, pkgs, lib, ... }:

let

  inherit (lib) mkIf mkOption types filterAttrs hasPrefix
                mapAttrsToList concatStringsSep concatMapStringsSep;
  inherit (types) listOf submodule path attrsOf;
  inherit (builtins) filter toString toFile isList isBool;

  cfg = config.nixsap.apps.strongswan;
  explicit = filterAttrs (n: v: n != "_module" && v != null);

  ipsecSecrets = toFile "ipsec.secrets" ''
    ${concatMapStringsSep "\n" (f: "include ${f}") cfg.secrets}
  '';

  ipsecConf =
    let
      show = k: v:
        if k == "charondebug" then concatStringsSep ","
              (mapAttrsToList (t: l: "${t} ${toString l}") (explicit v))
        else if isList v then concatStringsSep "," v
        else if isBool v then (if v then "yes" else "no")
        else toString v;
      makeSections = type: sections: concatStringsSep "\n\n" (
        mapAttrsToList (sec: attrs:
          "${type} ${sec}\n" +
            (concatStringsSep "\n" (
              mapAttrsToList (k: v: "  ${k}=${show k v}") (explicit attrs)
            ))
        ) (explicit sections)
      );
      setupSec = makeSections "config" { inherit (cfg) setup; }; 
      caSec = makeSections "ca" cfg.ca; 
      connSec = makeSections "conn" cfg.conn; 
    in toFile "ipsec.conf" ''
      ${setupSec}
      ${caSec}
      ${connSec}
    '';

  strongswanConf = toFile "strongswan.conf" ''
    charon { plugins { stroke { secrets_file = ${ipsecSecrets} } } }
    starter { config_file = ${ipsecConf } }
  '';

in {
  options.nixsap.apps.strongswan = {
    secrets = mkOption {
      description = ''
        A list of paths to IPSec secret files. These files will be included into
        the main ipsec.secrets file by the "include" directive
      '';
      type = listOf path;
      default = [];
    };
    setup = mkOption {
      description = ''
        A set of options for the ‘config setup’ section of the
        ipsec.conf file. Defines general configuration parameters
      '';
      type = submodule (import ./options/setup.nix);
      default = {};
    };
    ca = mkOption {
      description = ''
        A set of CAs (certification authorities) and their options for
        the ‘ca xxx’ sections of the ipsec.conf file
      '';
      type = attrsOf (submodule (import ./options/ca.nix));
      default = {};
    };
    conn = mkOption {
      description = ''
        A set of connections and their options for the ‘conn xxx’
        sections of the ipsec.conf file
      '';
      type = attrsOf (submodule (import ./options/conn.nix));
      default = {};
    };
  };

  config = mkIf ({} != explicit cfg.conn) {
    nixsap.deployment.keyrings.root = filter (hasPrefix "/run/keys/") cfg.secrets;
    environment.systemPackages = [ pkgs.strongswan ];
    systemd.services.strongswan = {
      description = "strongSwan IPSec Service";
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ config.system.sbin.modprobe iproute iptables utillinux ];
      wants = [ "keys.target" ];
      after = [ "network.target" "keys.target" "local-fs.target" ];
      environment = {
        STRONGSWAN_CONF = strongswanConf;
      };
      serviceConfig = {
        ExecStart  = "${pkgs.strongswan}/sbin/ipsec start --nofork";
        Restart = "always";
      };
    };
  };
}
