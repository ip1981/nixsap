{ haskell, haskellPackages }:

let myHaskellPkgs = haskellPackages.override {
  overrides = self: super: {
  };
};

in haskell.lib.justStaticExecutables (myHaskellPkgs.callPackage ./main.nix {})

