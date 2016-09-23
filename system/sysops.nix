{ config, lib, ...}:
let

  inherit (lib) concatMapStringsSep concatStringsSep mkOption types;
  inherit (types) str listOf;

  bindir = "/run/current-system/sw/bin";

  commands = concatStringsSep ", " (
    [
      "${bindir}/du *"
      "${bindir}/iftop"
      "${bindir}/iotop"
      "${bindir}/ip6tables -L*"
      "${bindir}/ipsec *"
      "${bindir}/iptables -L*"
      "${bindir}/journalctl *"
      "${bindir}/lsof *"
      "${bindir}/mtr *"
      "${bindir}/nix-collect-garbage *"
      "${bindir}/nmap *"
      "${bindir}/tcpdump *"
      "${bindir}/traceroute *"
    ] ++ map (c: "${bindir}/systemctl ${c} *")
        [ "kill" "reload" "restart" "start" "status" "stop" ]
  );

in {

  config = {
    security.sudo.extraConfig = ''
      %wheel ALL=(ALL) NOPASSWD: ${commands}
    '';
  };
}
