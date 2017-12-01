pkgs:
{ lib, name, config, ... }:

let

  inherit (builtins) all attrNames;

  inherit (lib)
    concatStrings filterAttrs hasSuffix mapAttrsToList mkOption ;

  inherit (lib.types)
    addCheck attrsOf either enum int listOf nullOr package path str submodule ;

  default = d: t: mkOption { type = t; default = d; };
  optional = t: mkOption { type = nullOr t; default = null; };
  readonly = d: t: mkOption { type = nullOr t; default = d; readOnly = true; };

in {
  options = {

    jre = {
      package = mkOption {
        description = "Java runtime package";
        default = pkgs.jre8;
        type = package;
      };

      properties = {
        hudson.model.DirectoryBrowserSupport.CSP = optional str;
        java.io.tmpdir = readonly "${config.home}/tmp" path;
        java.util.logging.config.file = optional path;
      };
    };

    war = mkOption {
      description = "Jenkins web application archive (WAR)";
      default = pkgs.jenkins;
      type = path;
    };

    user = mkOption {
      description = "User to run as";
      default = "jenkins-${name}";
      readOnly = true;
      type = str;
    };

    home = mkOption {
      description = "Jenkins data directory";
      type = path;
      default = "/jenkins/${name}";
    };

    jobs = mkOption {
      description = ''
        Jenkins jobs. Each value is either inline XML text or an XML file.
        Any existing jobs, not mentioned here, are physically removed.
      '';
      type = attrsOf (either str path);
      default = {};
    };

    config = mkOption {
      description = ''
        Jenkins XML configuration files. Either inline text or file. Any
        existing XML files, not mentioned here, are physically removed. You
        might want to add `config.xml` at least. You can use XInclude
        facility to include sensitive pieces of configuration like passwords
        or private keys.  Those grains  will be processed (expanded) to
        create proper configuration files. Also they will be automatically
        picked up and deployed (requires read-write mode of evaluation).
        E. g. if you write '<xi:include href="/run/keys/github-oauth.xml"/>',
        that file will be deployed as a secret key, and when Jenkins starts,
        that piece will be replaced by the file contents. All configuration
        files reside in Jenkins private directory so secrets remain secret.
      '';
      type = addCheck (attrsOf (either str path)) (aa: all (hasSuffix ".xml") (attrNames aa));
      default = {};
    };

    path = mkOption {
      description = ''
        Additional packages available to Jenkins in PATH.  You also may opt in specifying
        paths to executables in various config files.
      '';
      type = listOf package;
      default = [];
      example = [ pkgs.gitMinimal ];
    };

    options = {
      controlPort          = optional int;
      debug                = optional (enum [1 2 3 4 5 6 7 8 9]);
      httpKeepAliveTimeout = optional int;
      httpListenAddress    = default "127.0.0.1" str;
      httpPort             = default 8080 int;
      prefix               = optional str;
      sessionTimeout       = optional int;
    };

  };
}

