{ lib, ... }:

let
  all = lib.attrNames (
    lib.filterAttrs
    ( n: _: n != "default.nix" && ! lib.hasPrefix "." n )
    (builtins.readDir ./.)
  );

  localPackages = super: lib.listToAttrs (map (f:
    { name = lib.removeSuffix ".nix" f;
      value = super.callPackage (./. + "/${f}") {}; }
  ) all);

in {
  nixpkgs.config.packageOverrides = localPackages;
}

