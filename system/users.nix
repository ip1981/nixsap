{ config, pkgs, lib, ... }:

let

  inherit (builtins)
    genList hashString mul substring ;

  inherit (lib)
    foldl genAttrs imap mkOption stringToCharacters toLower
    types unique ;

  inherit (types)
    listOf str ;

  uid = name:
    let
      dec = {
        "0" =  0; "1" =  1; "2" =  2; "3" =  3;
        "4" =  4; "5" =  5; "6" =  6; "7" =  7;
        "8" =  8; "9" =  9; "a" = 10; "b" = 11;
        "c" = 12; "d" = 13; "e" = 14; "f" = 15;
      };
      base = 1000000000; # 2^32 > base + 16^7
      hex = toLower (substring 0 7 (hashString "sha1" name));
      pow = b: n: foldl mul 1 (genList (_: b) n);
      digits = imap (i: d: {m = pow 16 (i - 1); d = d;}) (stringToCharacters hex);
      f = a: {m, d}: a + m * dec.${d};

    in foldl f base digits;

  daemons = config.nixsap.system.users.daemons;
  normal = config.nixsap.system.users.normal;
  groups = config.nixsap.system.groups;

  mkGroup = name: { gid = uid name; };
  mkDaemonUser = name:
    {
      isNormalUser = false;
      uid = uid name;
      group = name;
    };

  mkNormalUser = name:
    {
      isNormalUser = true;
      uid = uid name;
    };

in {
  options.nixsap.system = {
    users.daemons = mkOption {
      type = listOf str;
      description = "List of system users with automatic UID and group";
      default = [];
    };
    users.normal = mkOption {
      type = listOf str;
      description = "List of regular users with automatic UID";
      default = [];
    };
    users.sysops = mkOption {
      description = ''
        List of local users with special roles in applications or system-wide.
        The users in this list are not create automatically.
      '';
      type = listOf str;
      default = [];
    };
    groups = mkOption {
      type = listOf str;
      description = "List of groups with automatic GID";
      default = [];
    };
  };

  # XXX: Modules for automatic unicity of user names:
  imports = [
    { users.groups = genAttrs (unique (daemons ++ groups)) mkGroup; }
    { users.users = genAttrs daemons mkDaemonUser; }
    { users.users = genAttrs normal mkNormalUser; }
  ];
}

