{ nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem
}:

let

  lib = import (nixpkgs + "/lib");
  inherit (lib) evalModules;


  evaluated = evalModules {
    modules = [
      { nixpkgs.system = system; }
      (import (nixpkgs + "/nixos/modules/misc/nixpkgs.nix"))
      (import ../modules/pkgs)
    ];
  };

  inherit (evaluated.config._module.args) pkgs;

in pkgs
