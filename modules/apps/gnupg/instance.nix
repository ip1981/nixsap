pkgs:
{ lib, name, ... }:

let

  inherit (lib)
    mkOption ;

  inherit (lib.types)
    attrsOf listOf package path str ;

in {
  options = {

    user = mkOption {
      description = ''
        User to run as ang keyring owner. This option is required.
        Note that this user is not created automatically.
      '';
      type = str;
    };

    home = mkOption {
      description = ''
        GnuPG home directory where keyrings and gpg-agent socket
        will be located.
      '';
      type = path;
      default = "/gnupg/${name}";
    };

    package = mkOption {
      description = "GnuPG2 package";
      type = package;
      default = pkgs.gnupg21;
    };

    publicKeys = mkOption {
      description = "Public GPG keys";
      type = listOf path;
      default = [];
    };

    secretKeys = mkOption {
      description = "Secret GPG keys";
      type = listOf path;
      default = [];
    };

    passphrase = mkOption {
      description = ''
        Secret files with pass-phrase to unlock secret keys.  Keys are
        identified by cacheid, which is either a 40 character keygrip of
        hexadecimal characters identifying the key or an arbitrary string
        identifying a passphrase. Refer to the `gpg-preset-passphrase`
        documentation, because it is what stays behind this mechanism.
        Generally in unattended environments you need to use keygrip.
      '';
      type = attrsOf path;
      default = {};
      example = {
        "ABCD...321" = "/run/keys/foo";
        "myapp:mykey" = "/run/keys/bar";
      };
    };
  };
}

