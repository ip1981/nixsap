{ config, lib, ... }:

let
  inherit (builtins) length toString replaceStrings;
  inherit (lib) flatten concatMapStringsSep optionalString splitString mkOption;
  inherit (lib.types) listOf int either submodule enum str;

  inherit (config.nixsap.system.firewall) whitelist;

  iptablesAllow = { dport, protocol, source, comment, ... }:
    let
      ports = concatMapStringsSep "," toString (flatten [dport]);
      iptables = if 1 < length (splitString ":" source)
                 then "ip6tables" else "iptables";
    in "${iptables} -w -A nixos-fw -m multiport "
     + "-p ${protocol} --dport ${ports} -s ${source} -j nixos-fw-accept"
     + optionalString (comment != "")
      " -m comment --comment '${replaceStrings ["'"] ["'\\''"] comment} '";

in {
  options.nixsap.system.firewall.whitelist = mkOption {
    description = "Inbound connection rules (whitelist)";
    default = [];
    type = listOf (submodule {
      options = {
        dport = mkOption {
          description = "Destination port or list of ports";
          type = either int (listOf int);
        };
        source = mkOption {
          description = "Source specification: a network IP address (with optional /mask)";
          type = str;
        };
        protocol = mkOption {
          description = "The network protocol";
          type = enum [ "tcp" "udp" ];
          default = "tcp";
        };
        comment = mkOption {
          description = "Free-form comment";
          type = str;
          default = "";
        };
      };
    });
  };

  config = {
    networking.firewall.extraCommands =
      concatMapStringsSep "\n" iptablesAllow whitelist;
  };
}
