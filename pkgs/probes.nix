{ stdenv, pkgs, lib }:

let
  plugins = [
    "check_disk"
    "check_file_age"
    "check_http"
    "check_load"
    "check_log"
    "check_mysql"
    "check_mysql_query"
    "check_procs"
    "check_swap"
    "check_users"
  ];

in stdenv.mkDerivation {
  name = "local-monitoring-plugins";
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/bin
    ${lib.concatMapStringsSep "\n" (p: ''
      cp -a ${pkgs.monitoringPlugins}/libexec/${p} $out/bin/${p}
     '') plugins}
    cp -a '${pkgs.check_mdstat}/bin/'* $out/bin/
    cp -a '${pkgs.check_systemd}/bin/'* $out/bin/
  '';
}
