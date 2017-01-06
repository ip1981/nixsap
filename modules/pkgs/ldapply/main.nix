{ mkDerivation, base, bytestring, docopt, fetchgit
, interpolatedstring-perl6, LDAP, ldif, stdenv
, unordered-containers
}:
mkDerivation {
  pname = "ldapply";
  version = "0.1.0";
  src = fetchgit {
    url = "https://github.com/ip1981/ldapply.git";
    sha256 = "0vmq6l49hiyc20rv6xqj518m6bn7291ampjd1yf2b6w79isx3zfg";
    rev = "cdddf52e87b0b7a84b9b664df29004340f99ec20";
  };
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    base bytestring docopt interpolatedstring-perl6 LDAP ldif
    unordered-containers
  ];
  description = "LDIF idempotent apply tool";
  license = stdenv.lib.licenses.mit;
}
