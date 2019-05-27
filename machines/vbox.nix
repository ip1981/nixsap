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
    headless = mkDefault true;
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
    fileSystems."${apps.nginx.stateDir}" = mkIf (apps.nginx.conf.http.servers != {}) 1;
    fileSystems."/jenkins" = mkIf (apps.jenkins != {}) 15;
    fileSystems."/mariadb" = mkIf apps.mariadb.enable 30;
    fileSystems."/postgresql" = mkIf (apps.postgresql != {}) 2;
    fileSystems."/tmp" = 1;
  };

  nixsap.apps.icinga2.notifications = mkForce false;

  nixsap.apps.mariadb.mysqld = {
    datadir = mkForce "/mariadb/db";
    innodb_buffer_pool_size = (40 * memorySize) / 100;
    log_bin = mkForce "/mariadb/binlog/binlog";
    relay_log = mkForce "/mariadb/relay/relay";
    server_id = mkForce 1;
    ssl_cert = mkForce "${pkgs.fakeSSL}/cert.pem";
    ssl_key = mkForce "${pkgs.fakeSSL}/key.pem";
  };

  nixsap.apps.sproxy2 = {
    ssl_cert = mkForce "${pkgs.fakeSSL}/cert.pem";
    ssl_key = mkForce "${pkgs.fakeSSL}/key.pem";
  };

  nixsap.apps.sproxy-web = {
    connectionString = mkForce "user=sproxy dbname=sproxy port=${toString apps.postgresql.fcebkl.server.port}";
  };

  nixsap.apps.mediawiki.localSettings = {
    wgDBerrorLog = "/tmp/wiki-db.log";
    wgDebugLogFile = "/tmp/wiki.log";
    wgShowDBErrorBacktrace = true;
    wgShowExceptionDetails = true;
  };

  security.sudo.wheelNeedsPassword = mkForce false;
  environment.systemPackages = with pkgs; [
    curl file htop iftop iotop jq lsof mc mtr ncdu netcat nmap openssl
    pigz pv pwgen pxz sysstat tcpdump telnet tmux traceroute tree vim wget
  ];

  programs.bash.enableCompletion = mkForce true;

  services.openssh.authorizedKeysFiles = mkForce [
    "/etc/ssh/authorized_keys.d/%u"
    "/root/.ssh/authorized_keys"
    "/root/.vbox-nixops-client-key"
  ];

  nixsap.apps.postgresql.fcebkl = mkIf apps.sproxy-web.enable {
    package = pkgs.postgresql95;
    server = {
      data_directory = "/postgresql/9.5/fcebkl";
      port = 9999;
      hba_file = ''
        local   sproxy      all              peer      map=sproxymap
      '';
      ident_file = ''
        sproxymap ${apps.sproxy2.user}     sproxy-readonly
        sproxymap ${apps.sproxy-web.user}  sproxy
      '';
    };
    roles = [ "sproxy" "sproxy-readonly" ];
    databases = [ "sproxy" ];
    configure = ''
      ALTER ROLE sproxy LOGIN;
      ALTER ROLE "sproxy-readonly" LOGIN;
      ALTER DATABASE sproxy OWNER TO sproxy;

      \c sproxy;
      SET ROLE sproxy;

      GRANT SELECT ON ALL TABLES IN SCHEMA public TO "sproxy-readonly";
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO "sproxy-readonly";

      BEGIN;
        CREATE TABLE IF NOT EXISTS "group" (
          "group" TEXT NOT NULL PRIMARY KEY
        );
        CREATE TABLE IF NOT EXISTS group_member (
          "group" TEXT REFERENCES "group" ("group") ON UPDATE CASCADE ON DELETE CASCADE NOT NULL,
          email TEXT NOT NULL,
          PRIMARY KEY ("group", email)
        );
        CREATE TABLE IF NOT EXISTS domain (
          domain TEXT NOT NULL PRIMARY KEY
        );
        CREATE TABLE IF NOT EXISTS privilege (
          "domain" TEXT REFERENCES domain (domain) ON UPDATE CASCADE ON DELETE CASCADE NOT NULL,
          privilege TEXT NOT NULL,
          PRIMARY KEY ("domain", privilege)
        );
        CREATE TABLE IF NOT EXISTS privilege_rule (
          "domain" TEXT NOT NULL,
          privilege TEXT NOT NULL,
          "path" TEXT NOT NULL,
          "method" TEXT NOT NULL,
          FOREIGN KEY ("domain", privilege) REFERENCES privilege ("domain", privilege) ON UPDATE CASCADE ON DELETE CASCADE,
          PRIMARY KEY ("domain", "path", "method")
        );
        CREATE TABLE IF NOT EXISTS group_privilege (
          "group" TEXT REFERENCES "group" ("group") ON UPDATE CASCADE ON DELETE CASCADE NOT NULL,
          "domain" TEXT NOT NULL,
          privilege TEXT NOT NULL,
          FOREIGN KEY ("domain", privilege) REFERENCES privilege ("domain", privilege) ON UPDATE CASCADE ON DELETE CASCADE,
          PRIMARY KEY ("group", "domain", privilege)
        );
      COMMIT;

      BEGIN;
        INSERT INTO domain (domain) VALUES ('%') ON CONFLICT DO NOTHING;
        INSERT INTO "group" ("group") VALUES ('all') ON CONFLICT DO NOTHING;
        INSERT INTO "group" ("group") VALUES ('devops') ON CONFLICT DO NOTHING;
        INSERT INTO "group" ("group") VALUES ('foo') ON CONFLICT DO NOTHING;
        INSERT INTO group_member ("group", email) VALUES ('all', '%') ON CONFLICT DO NOTHING;
        INSERT INTO group_member ("group", email) VALUES ('devops', '%') ON CONFLICT DO NOTHING;
        INSERT INTO group_member ("group", email) VALUES ('foo', '%') ON CONFLICT DO NOTHING;
        INSERT INTO privilege (domain, privilege) VALUES ('%', 'full') ON CONFLICT DO NOTHING;
        INSERT INTO group_privilege ("group", domain, privilege) VALUES ('all', '%', 'full') ON CONFLICT DO NOTHING;
        INSERT INTO group_privilege ("group", domain, privilege) VALUES ('devops', '%', 'full') ON CONFLICT DO NOTHING;
        INSERT INTO group_privilege ("group", domain, privilege) VALUES ('foo', '%', 'full') ON CONFLICT DO NOTHING;
        INSERT INTO privilege_rule (domain, privilege, path, method) VALUES ('%', 'full', '%', '%') ON CONFLICT DO NOTHING;
      COMMIT;

      RESET ROLE;
      \c postgres;
    '';
  };
}
