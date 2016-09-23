{ config, lib, ... }:
with lib;
with lib.types;
let
  mandatory = type: mkOption { inherit type; };
  optional = type: mkOption { type = nullOr type; default = null; };

  common = foldl (a: b: a//b) {} [
    { host                   = mandatory str; }
    { password-file          = optional path; }
    { port                   = optional int; }
    { ssl                    = optional bool; }
    { ssl-ca                 = optional path; }
    { ssl-cert               = optional path; }
    { ssl-key                = optional path; }
    { ssl-verify-server-cert = optional bool; }
    { user                   = mandatory str; }
  ];

  master.options = foldl (a: b: a//b) {} [
    { connect-retry    = optional int; }
    { heartbeat-period = optional int; }
    common
  ];

  mysqldump.options = foldl (a: b: a//b) {} [
    { compress           = optional bool; }
    { lock-tables        = optional bool; }
    { path               = optional path; }
    { single-transaction = optional bool; }
    common
  ];

in {
  options = {
    databases = mkOption {
      type = listOf str;
      description = ''
        List of databases to dump and replicate.  This will be written as
        `foo.replicate_wild_do_table = db.%`.
        '';
      example = [ "oms_live_sg" "bob_live_sg" ];
    };

    ignore-tables = mkOption {
      type = listOf str;
      description = ''
        List of tables to ignore.  This will be written as
        `foo.replicate_ignore_table = db.table`.  If database prefix is
        omitted, expressions for all databases will be generated.
        '';
      example = [ "schema_updates" "bob_live_sg.locks" ];
      default = [];
    };

    ignore-databases = mkOption {
      type = listOf str;
      description = ''
        List of databases to ignore. You do not need this in most cases.
        See http://dev.mysql.com/doc/refman/en/replication-rules.html.
        This will be written as `foo.replicate_ignore_db = mysql`.  This is
        useful when you want procedures in other databases, like `mysql`,
        not to be replicated.
        '';
      default = [ "mysql" "test" "tmp" ];
    };

    master = mkOption { type = submodule (master); };
    mysqldump = mkOption { type = submodule (mysqldump); };
  };

  config = {
    mysqldump = {
      compress           = mkDefault true;
      host               = mkDefault config.master.host;
      password-file      = mkDefault config.master.password-file;
      port               = mkDefault config.master.port;
      single-transaction = mkDefault true;
      ssl                = mkDefault config.master.ssl;
      ssl-ca             = mkDefault config.master.ssl-ca;
      ssl-cert           = mkDefault config.master.ssl-cert;
      ssl-key            = mkDefault config.master.ssl-key;
      user               = mkDefault config.master.user;
    };
  };
}

