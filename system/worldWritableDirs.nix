{ config, pkgs, lib, ... }:
let
  dirs = config.nixsap.system.worldWritableDirs;

in {
  options.nixsap.system.worldWritableDirs = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    description = "These dirs will be chmod'ed 1777";
    default = [ "/tmp" "/var/tmp" ];
  };

  config = lib.mkIf (dirs != []) {
    systemd.services.chmod1777 = {
      description = "Make some dirs world-writable";
      unitConfig.RequiresMountsFor = dirs;
      before = [ "local-fs.target" ];
      wantedBy = [ "local-fs.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.coreutils}/bin/chmod -c 1777 ${lib.concatStringsSep " " dirs}";
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
