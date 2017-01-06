{ mkDerivation, base, fetchgit, HUnit, openldap, stdenv }:
mkDerivation {
  pname = "LDAP";
  version = "0.7.0";
  src = fetchgit {
    url = "https://github.com/ip1981/ldap-haskell.git";
    sha256 = "1lb746ifqz216cxgxli30r30bx49f8l1an4k4w7sa87gdchjka4y";
    rev = "1d47f5712fc09bbf00c49bb58907aaf355fdf2e2";
  };
  libraryHaskellDepends = [ base ];
  librarySystemDepends = [ openldap ];
  testHaskellDepends = [ base HUnit ];
  testSystemDepends = [ openldap ];
  homepage = "https://github.com/ezyang/ldap-haskell";
  description = "Haskell binding for C LDAP API";
  license = stdenv.lib.licenses.bsd3;
}
