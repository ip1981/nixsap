{ mkDerivation, base, bytestring, docopt, interpolatedstring-perl6
, LDAP, ldif, stdenv, unordered-containers
}:
mkDerivation {
  pname = "ldapply";
  version = "0.2.0";
  sha256 = "0qgpb22k9krdhwjydzyfhjf85crxc49ss7x74mrqj8ivkzg5hl28";
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    base bytestring docopt interpolatedstring-perl6 LDAP ldif
    unordered-containers
  ];
  description = "LDIF idempotent apply tool";
  license = stdenv.lib.licenses.mit;
}
