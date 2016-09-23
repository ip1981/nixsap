{ mkDerivation, aeson, base, bytestring, ConfigFile
, data-default-class, docopt, fast-logger, fetchgit, http-types
, interpolatedstring-perl6, MissingH, mtl, mysql, mysql-simple
, network, resource-pool, scotty, stdenv, text, unix
, unordered-containers, wai, wai-extra, wai-middleware-static, warp
}:
mkDerivation {
  pname = "mywatch";
  version = "0.2.0";
  src = fetchgit {
    url = "https://github.com/zalora/mywatch.git";
    sha256 = "f1ae1b776cdbc11da24819381d5d1fe057be3c5ef69314024c9e0fc043085cd2";
    rev = "afd12c0190f64527a320a99cc6df97f6cfca57d7";
  };
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson base bytestring ConfigFile data-default-class docopt
    fast-logger http-types interpolatedstring-perl6 MissingH mtl mysql
    mysql-simple network resource-pool scotty text unix
    unordered-containers wai wai-extra wai-middleware-static warp
  ];
  description = "Web application to view and kill MySQL queries";
  license = stdenv.lib.licenses.mit;
}
