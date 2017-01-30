pkgs:
{ lib, name, ... }:

let

  inherit (builtins) match ;

  inherit (lib)
    mkOption mkOptionType ;

  inherit (lib.types)
    bool either enum int listOf nullOr package path str submodule ;

  default = v: type: mkOption { type = type; default = v; };
  optional = type: mkOption { type = nullOr type; default = null; };

  isFloat = x: match "^[0-9]+(\\.[0-9]+)?$" (toString x) != null;

  float = mkOptionType {
    name = "positive float";
    check = isFloat;
  };

in {
  options = {

    user = mkOption {
      description = "User to run as";
      type = str;
      default = "memcached-${name}";
    };

    package = mkOption {
      description = "Memcached package";
      type = package;
      default = pkgs.memcached;
    };

    args = mkOption {
      description = "Memcached command line arguments. Refer to memcached man page.";
      default = {};
      type = submodule {
        options = {
          M = optional bool;
          R = optional int;
          B = optional (enum ["auto" "ascii" "binary"]);
          I = optional int;
          L = optional bool;
          l = default "127.0.0.1" (either str (listOf str));
          b = optional int;
          c = optional int;
          f = optional float;
          p = default 11211 int;
          t = optional int;
          D = optional str;
          a = optional str;
          m = optional int;
          n = optional int;
          F = optional bool;
          U = default 11211 int;
          C = optional bool;
          k = optional bool;
          A = optional bool;
          S = optional bool;
          s = optional path;
        };
      };
    };
  };
}

