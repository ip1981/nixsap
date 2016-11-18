{ mkDerivation, base, base64-bytestring, bytestring
, data-default-class, docopt, entropy, fast-logger, fetchgit
, http-types, interpolatedstring-perl6, mtl, mysql, mysql-simple
, network, resource-pool, scotty, stdenv, text, unix, wai
, wai-extra, wai-middleware-static, warp
}:
mkDerivation {
  pname = "juandelacosa";
  version = "0.1.1";
  src = fetchgit {
    url = "https://github.com/zalora/juandelacosa.git";
    sha256 = "c260feae989f518484881e7dc7ebcd51d5b25fcda92412445942a5e34c1f9459";
    rev = "0940da0cdfb1201768d35c58433891feacbaedd5";
  };
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    base base64-bytestring bytestring data-default-class docopt entropy
    fast-logger http-types interpolatedstring-perl6 mtl mysql
    mysql-simple network resource-pool scotty text unix wai wai-extra
    wai-middleware-static warp
  ];
  description = "Manage users in MariaDB >= 10.1.1";
  license = stdenv.lib.licenses.mit;
}
