{ config, lib, ... }:

let

  inherit (lib) foldl genAttrs;
  inherit (import ./lib.nix lib) boolean boolOr default optional set enum';

  charondebug = genAttrs [
    "asn" "cfg" "chd" "dmn"
    "enc" "esp" "ike" "imc"
    "imv" "job" "knl" "lib"
    "mgr" "net" "pts" "tls"
    "tnc"
  ] (_: optional (enum' [ (-1) 0 1 2 3 4 ]));

in {
  options = foldl (a: b: a//b) {} [
    { cachecrls       = optional boolean; }
    { charondebug     = set charondebug; }
    { charonstart     = optional boolean; }
    { strictcrlpolicy = optional (boolOr [ "ifuri" ]); }
    { uniqueids       = optional (boolOr [ "never" "replace" "keep" ]); }
  ];
}
