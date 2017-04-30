{ config, lib, ... }:
 
let

  inherit (builtins)
    attrNames baseNameOf head match pathExists readFile ;
  inherit (lib)
    filter foldl genAttrs hasPrefix mapAttrsToList mkOption
    optionalAttrs unique ;
  inherit (lib.types)
    attrsOf listOf nullOr path ;

  allusers = config.users.users;
  cfg = config.nixsap.deployment;

  # XXX If the file is encrypted:
  #     error: the contents of the file ‘...’ cannot be represented as a Nix string
  read = key:
    let
      m = match "^(.+)@[^@]+$" key;
      s = if m != null then head m else key;
    in if cfg.secrets != null
      then readFile (cfg.secrets + "/${s}")
      else "";

in {
  options.nixsap.deployment = {
    secrets = mkOption {
      description = ''
        Directory with the secrets on the deploy machine. If not specified,
        each key will be an empty file.
        '';
      type = nullOr path;
      default = null;
      example = "<secrets>";
    };

    keyStore = mkOption {
      description = ''
        Directory with the keys on the target machine.  NixOps uses /run/keys,
        and this is default.  If you use another deployment tool, you would
        like to set it to something else.
        '';
      type = path;
      default = "/run/keys";
      example = "/root/keys";
    };

    keyrings = mkOption {
      type = attrsOf (listOf (nullOr path));
      description = ''
        Binds keys to a user. It's possible to share the same key between
        multiple users, of course by different names: "/run/keys/foo"
        and "/run/keys/foo@bar" will use the same secret file "foo". Any
        file whose path does not start with `nixsap.deployment.keyStore` is
        deliberately ignored. E. i. you can pass any file names, and nixsap
        will pick up keys for you. For convenience, it is allowed to pass
        null values, which are filtered-out as well.
      '';
      default = {};
      example = { mysqlbackup = [ "/run/keys/s3cmd.cfg" ];
                  pgbackup = [ "/run/keys/s3cmd.cfg@pgbackup" ];
                };
    };
  };

  config = {
    users.users = genAttrs (attrNames cfg.keyrings) (
      name: optionalAttrs (name != "root") { extraGroups = [ "keys" ]; }
    );

    deployment.keys = foldl (a: b: a//b) {} (
      mapAttrsToList (name: keys:
        let realkeys = unique (filter (n: n != null && hasPrefix cfg.keyStore n) keys);
        in genAttrs (map baseNameOf realkeys)
                 (key: { text = read key;
                         user = toString allusers.${name}.uid;
                       })
      ) cfg.keyrings
    );
  };
}
