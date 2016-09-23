{ config, lib, ... }:

let

  inherit (lib) foldl;
  inherit (lib.types) str path enum;
  inherit (import ./lib.nix lib) optional;

in {
  options = foldl (a: b: a//b) {} [
    { also        = optional str; }
    { auto        = optional (enum [ "add" "ignore" ]); }
    { cacert      = optional path; }
    { certuribase = optional str; }
    { crluri      = optional str; }
    { crluri2     = optional str; }
    { ocspuri     = optional str; }
    { ocspuri2    = optional str; }
  ];
}
