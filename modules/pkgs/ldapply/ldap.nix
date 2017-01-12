{ mkDerivation, base, HUnit, cyrus_sasl, openldap, stdenv }:
mkDerivation {
  pname = "LDAP";
  version = "0.6.11";
  doCheck = false; # XXX: missing file in tarball
  sha256 = "1cwh3272zi5r0zznmixghf87vskz7s35bmz6ifyky0xk3s04ijq1";
  libraryHaskellDepends = [ base ];
  librarySystemDepends = [ cyrus_sasl openldap ];
  testHaskellDepends = [ base HUnit ];
  testSystemDepends = [ openldap ];
  homepage = "https://github.com/ezyang/ldap-haskell";
  description = "Haskell binding for C LDAP API";
  license = stdenv.lib.licenses.bsd3;
}
