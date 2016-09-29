# This is for NixOps (https://nixos.org/nixops/)

{ config, pkgs, lib, ... }:
let
  inherit (config.nixsap) apps;
  inherit (lib) mkForce mkDefault mkIf;
  inherit (pkgs) writeText;
  memorySize = config.deployment.virtualbox.memorySize * 1024 * 1024;
in {
  deployment.targetEnv = "virtualbox";
  deployment.virtualbox = {
    memorySize = mkDefault 1024; # megabytes
    disks = {
      sdb = { port = 1; size = 30000; };
      sdc = { port = 2; size = 30000; };
      sdd = { port = 4; size = 2000; };
    };
  };
  swapDevices = [{ device = "/dev/sdd"; randomEncryption = true; }];


  nixsap.system.lvm.raid0.apps = {
    stripes = 2;
    units = "g";
    physical = [ "/dev/sdb" "/dev/sdc" ];
    fileSystems."${apps.icinga2.stateDir}" = mkIf apps.icinga2.enable 1;
    fileSystems."${apps.icingaweb2.configDir}" = mkIf apps.icingaweb2.enable 1;
    fileSystems."${apps.mysqlbackup.dumpDir}" = mkIf (apps.mysqlbackup.servers != {}) 10;
    fileSystems."${apps.nginx.stateDir}" = mkIf (apps.nginx.http.servers != {}) 1;
    fileSystems."/mariadb" = mkIf apps.mariadb.enable 30;
    fileSystems."/postgresql" = mkIf (apps.postgresql != {}) 2;
    fileSystems."/tmp" = 1;
  };

  nixsap.apps.filebackup.s3uri = mkForce null;
  nixsap.apps.icinga2.notifications = mkForce false;
  nixsap.apps.mysqlbackup.s3uri = mkForce null;
  nixsap.apps.pgbackup.s3uri = mkForce null;

  nixsap.apps.mariadb.mysqld = {
    datadir = mkForce "/mariadb/db";
    innodb_buffer_pool_size = (40 * memorySize) / 100;
    log_bin = mkForce "/mariadb/binlog/binlog";
    relay_log = mkForce "/mariadb/relay/relay";
    server_id = mkForce 1;
    ssl_cert = mkForce "${pkgs.fakeSSL}/cert.pem";
    ssl_key = mkForce "${pkgs.fakeSSL}/key.pem";
  };

  nixsap.apps.sproxy = {
    sslCert = mkForce "${pkgs.fakeSSL}/cert.pem";
    sslKey = mkForce "${pkgs.fakeSSL}/key.pem";
    cookieName = mkForce "sproxy_vbox";
    logLevel = mkForce "debug";
  };

  nixsap.apps.mediawiki.localSettings = {
    wgDBerrorLog = "/tmp/wiki-db.log";
    wgDebugLogFile = "/tmp/wiki.log";
    wgShowDBErrorBacktrace = true;
    wgShowExceptionDetails = true;
  };

  security.sudo.wheelNeedsPassword = mkForce false;
  environment.systemPackages = with pkgs; [
    atop curl file htop iftop iotop jq lsof mc mtr ncdu netcat nmap openssl
    pigz pv pwgen pxz sysstat tcpdump telnet tmux traceroute tree vim wget
  ];

  programs.bash.enableCompletion = mkForce true;

  services.openssh.authorizedKeysFiles = mkForce [
    "/etc/ssh/authorized_keys.d/%u"
    "/root/.ssh/authorized_keys"
    "/root/.vbox-nixops-client-key"
  ];
}
