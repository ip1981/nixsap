{ config, lib, ...}:
let

  inherit (lib) concatStringsSep genAttrs mkIf ;

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

  config = mkIf ( [] != config.nixsap.system.users.sysops ) {
    nixsap.system.groups = [ "sysops" ];

    users.users = genAttrs config.nixsap.system.users.sysops (
      name: {
        extraGroups = [ "sysops" "systemd-journal" "proc" ];
      }
    );

    security.sudo.extraConfig = ''
      %sysops ALL=(ALL) NOPASSWD: ${commands}
    '';
  };
}
