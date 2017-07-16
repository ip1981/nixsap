{ stdenv, pkgs, nodejs }:

let

  plugins = (import ./plugins.nix {
    inherit pkgs;
    inherit (pkgs) nodejs;
    inherit (stdenv) system;
  });

in plugins
