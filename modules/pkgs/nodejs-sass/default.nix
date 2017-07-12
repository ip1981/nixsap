{ stdenv, pkgs, nodejs, writeScript }:

let

  version = "4.5.3";

  main = (import ./main.nix {
    inherit pkgs;
    inherit (pkgs) nodejs;
    inherit (stdenv) system;
  })."node-sass-${version}";

in
pkgs.runCommand "nodejs-sass-${version}" {}
''
  mkdir -p $out/bin
  ln -s ${main}/lib/node_modules/node-sass/bin/node-sass $out/bin/node-sass
''
