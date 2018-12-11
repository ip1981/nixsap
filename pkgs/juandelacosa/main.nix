{ mkDerivation, base, base64-bytestring, bytestring
, data-default-class, docopt, entropy, fast-logger, http-types
, interpolatedstring-perl6, mtl, mysql, mysql-simple, network
, resource-pool, scotty, stdenv, text, unix, wai, wai-extra
, wai-middleware-static, warp
}:
mkDerivation {
  pname = "juandelacosa";
  version = "0.1.1";
  sha256 = "060zq739i3xhr7w448p460r7x3jyyzf7pn61abp7f9g8vjn6vqw7";
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
