{ stdenv, pkgs, nodejs, writeScript }:

let

  inherit (builtins)
    attrNames
    fromJSON
    head
    readFile
    ;

  packages = fromJSON (readFile ./main.json);
  package = head packages;

  name = head (attrNames package);
  version = package.${name};

  main = (import ./main.nix {
    inherit pkgs;
    inherit (pkgs) nodejs;
    inherit (stdenv) system;
  })."${name}-${version}";

in
pkgs.runCommand "${name}-${version}" {}
''
  mkdir -p $out/bin
  ln -s ${main}/bin/${name} $out/bin/${name}
  test -x $out/bin/${name}
''
