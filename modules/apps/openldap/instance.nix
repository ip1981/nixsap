pkgs:
{ config, lib, name, ... }:

let

  inherit (lib)
    mkOption mkOrder ;

  inherit (lib.types)
    either enum int lines listOf nullOr package path str ;

  optional = t: mkOption { type = nullOr t; default = null; };
  default = d: t: mkOption { type = t; default = d; };

in {
  options = {

    user = mkOption {
      description = "User to run as";
      type = str;
      default = "openldap-${name}";
    };

    package = mkOption {
      description = "OpenLDAP package";
      type = package;
      default = pkgs.openldap;
    };

    home = mkOption {
      description = ''
        OpenLDAP home directory, where all the databases are stored,
        including `cn=config`.
        '';
      type = path;
      default = "/openldap/${name}";
    };

    debugLevel = mkOption {
      description = "What to log";
      type = listOf (enum [
        "acl" "any" "args" "ber" "config" "conns" "filter" "none"
        "packets" "parse" "pcache" "shell" "stats" "stats2" "sync"
        "trace"
        ]);
      default = [ "acl" "ber" "config" "conns" ];
    };

    urlList = mkOption {
      description = ''
        Passed as is for the -h option to slapd.  Note that one more url
        ldapi:// will be passed anyway for internal maintenance.
        '';
      type = str;
      default = "ldap://127.0.0.1";
      example = "ldapi://%2Ftmp%2Fldapi ldaps:///";
    };

    "cn=config" = {
      olcConnMaxPending        = optional int;
      olcConnMaxPendingAuth    = optional int;
      olcIdleTimeout           = optional int;
      olcReferral              = default [] (listOf str);
      olcTLSCACertificateFile  = optional path;
      olcTLSCACertificatePath  = optional path;
      olcTLSCRLCheck           = optional (enum ["none" "peer" "all"]);
      olcTLSCRLFile            = optional path;
      olcTLSCertificateFile    = optional path;
      olcTLSCertificateKeyFile = optional path;
      olcTLSCipherSuite        = optional str;
      olcTLSDHParamFile        = optional path;
      olcTLSRandFile           = optional path;
      olcTLSVerifyClient       = optional (enum ["never" "allow" "try"]);
      olcThreads               = optional int;
      olcWriteTimeout          = optional int;

      ldif = mkOption {
        description = ''
          OpenLDAP configuration in LDIF format. This is fed to the slapadd
          utility before slapd is started and completely replaces any existing
          slapd configuration (`cn=config`). You may include schema files
          here, add databases, load modules. Any `olcDbDirectory` mentioned
          here will be automatically created iff it is under home directory.
          To configure `cn=config` itself use dedicated options.
        '';
        type = lines;
        example = ''
          dn: olcDatabase={1}mdb,cn=config
          objectClass: olcDatabaseConfig
          objectClass: olcMdbConfig
          olcAccess: {0}to attrs=userPassword 
           by anonymous auth 
           by * break
          olcAccess: {1}to dn.subtree="dc=example,dc=com" 
           by dn="cn=admin,dc=example,dc=com" write 
           by * break
          olcDatabase: {1}mdb
          olcDbCheckpoint: 512 30
          olcDbDirectory: $\{apps.openldap.foo.home\}/example.com
          olcDbIndex: cn eq
          olcDbMaxSize: 1073741824
          olcSuffix: dc=example,dc=com
        '';
      };
    };

    apply = mkOption {
      description = ''
        LDIF files to apply. This data is idempotently applied by the
        `ldapply` tool. Useful for initial configuration.  These files are
        processed in order, after slapd is started and ready.  Important
        note: if you want to apply to a specific tree/object, make sure to
        append 'by * break' to any access rule targeting this tree/object.
        Otherwise internal maintenance script will not be able to operate.
        For example, 'olcAccess: to dn.subtree="dc=example,dc=com" by
        dn="cn=admin,dc=example,dc=com" write by * break'. This is because
        the default rule is 'by * none stop'.
      '';
      type = listOf (either str path);
      default = [];
      example = [ "/foo/addusers.ldif" "/run/keys/set_passwords.ldif" ];
    };
  };

  config = {
    "cn=config".ldif = mkOrder 0 ''
      include: file://${config.package}/etc/openldap/schema/core.ldif
      include: file://${config.package}/etc/openldap/schema/cosine.ldif
      include: file://${config.package}/etc/openldap/schema/inetorgperson.ldif
    '';
  };
}

