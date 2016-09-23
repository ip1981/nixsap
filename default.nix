{ lib, ... }:

let
  all = lib.filterAttrs
    ( n: _: n != "default.nix"
           && ! lib.hasPrefix "." n
           && ! lib.hasPrefix "LICENSE" n
           && ! lib.hasPrefix "README" n
           && ! lib.hasPrefix "ChangeLog" n
           && ! lib.hasPrefix "TODO" n
    ) (builtins.readDir ./.);

in {
  imports = map (p: ./. + "/${p}") ( builtins.attrNames all );
}

