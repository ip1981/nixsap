{ haskell, haskellPackages }:

let myHaskellPkgs = haskellPackages.override {
  overrides = self: super: {
    mysql        = haskell.lib.dontCheck super.mysql;
    mysql-simple = haskell.lib.dontCheck super.mysql-simple;
  };
};

in myHaskellPkgs.callPackage ./main.nix { }

