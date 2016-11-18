{ haskellPackages }:

/*
  XXX: Sproxy2 need some libraries missed in nixpkgs 16.09
*/

let myHaskellPkgs = haskellPackages.override {
  overrides = self: super: {
    http-client     = self.callPackage ./http-client.nix {};
    http-client-tls = self.callPackage ./http-client-tls.nix {};
    http-conduit    = self.callPackage ./http-conduit.nix {};
  };
};

in myHaskellPkgs.callPackage ./main.nix { }

