{ config, lib, ... }:
 
let

  inherit (builtins)
    attrNames baseNameOf head match pathExists readFile toString ;
  inherit (lib)
    foldl genAttrs mapAttrsToList mkOption optionalAttrs types ;
  inherit (types)
    attrsOf listOf nullOr path ;

  allusers = config.users.users;
  cfg = config.nixsap.deployment;

  # XXX If the file is encrypted:
  #     error: the contents of the file ‘...’ cannot be represented as a Nix string
  read = key:
    let
      m = match "^([^(]*)\\[.+\\]$" key;
      s = if m != null then head m else key;
    in if cfg.secrets != null
      then readFile (cfg.secrets + "/${s}")
      else "";

in {
  options.nixsap.deployment = {
    secrets = mkOption {
      description = ''
        Directory with the secrets. If not specified,
        each key will be an empty file.
        '';
      type = nullOr path;
      default = null;
      example = "<secrets>";
    };
    keyrings = mkOption {
      type = attrsOf (listOf path);
      description = ''
        Binds keys to a user. It's possible to share the same key between
        multiple users, of course by different names: "/run/keys/foo" and
        "/run/keys/foo[bar]" will use the same secret file "foo".
      '';
      default = {};
      example = { mysqlbackup = [ "/run/keys/s3cmd.cfg" ];
                  pgbackup = [ "/run/keys/s3cmd.cfg[pgbackup]" ];
                };
    };
  };

  config = {
    users.users = genAttrs (attrNames cfg.keyrings) (
      name: optionalAttrs (name != "root") { extraGroups = [ "keys" ]; }
    );

    deployment.keys = foldl (a: b: a//b) {} (
      mapAttrsToList (name: keys:
        genAttrs (map baseNameOf keys)
                 (key: { text = read key;
                         user = toString allusers.${name}.uid;
                       })
      ) cfg.keyrings
    );
  };
}
