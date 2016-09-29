{lib, ... }:

let
  all = lib.filterAttrs
    ( n: _: n != "default.nix" && ! lib.hasPrefix "." n )
    (builtins.readDir ./.);

in {
  imports = map (p: ./. + "/${p}") ( builtins.attrNames all );
}

