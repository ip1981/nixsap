{ haskell, haskellPackages, openldap }:

let myHaskellPkgs = haskellPackages.override {
  overrides = self: super: {
    LDAP = self.callPackage ./ldap.nix { inherit openldap; }; # Version with ldapTrivialExternalSaslBind
    ldif = haskell.lib.dontCheck super.ldif; # requires ancient HUnit == 1.2.*
  };
};

in myHaskellPkgs.callPackage ./main.nix { }

