self: super:
let
  all = super.lib.attrNames (
    super.lib.filterAttrs
    ( n: _: n != "default.nix" && ! super.lib.hasPrefix "." n )
    (builtins.readDir ./.)
  );
in super.lib.listToAttrs (map (f:
  { name = super.lib.removeSuffix ".nix" f;
    value = super.callPackage (./. + "/${f}") {}; }
) all)

