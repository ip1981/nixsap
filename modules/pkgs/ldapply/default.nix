{ haskell, haskellPackages }:

let myHaskellPkgs = haskellPackages.override {
  overrides = self: super: {
    LDAP = self.callPackage ./ldap.nix { }; # Version with ldapExternalSaslBind
    ldif = haskell.lib.dontCheck super.ldif; # requires ancient HUnit == 1.2.*
  };
};

in myHaskellPkgs.callPackage ./main.nix { }

