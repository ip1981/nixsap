let

  inherit (import <nixpkgs/lib>) evalModules;


  evaluated = evalModules {
    modules = [
      { nixpkgs.system = builtins.currentSystem; }
      (import <nixpkgs/nixos/modules/misc/nixpkgs.nix>)
      (import ../modules/pkgs)
    ];
  };

  inherit (evaluated.config._module.args) pkgs;

in pkgs
