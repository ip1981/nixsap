{ mkDerivation, aeson, base, bytestring, ConfigFile
, data-default-class, docopt, fast-logger, fetchgit, http-types
, interpolatedstring-perl6, MissingH, mtl, mysql, mysql-simple
, network, resource-pool, scotty, stdenv, text, unix
, unordered-containers, wai, wai-extra, wai-middleware-static, warp
}:
mkDerivation {
  pname = "mywatch";
  version = "0.2.1";
  src = fetchgit {
    url = "https://github.com/zalora/mywatch.git";
    sha256 = "7c646cb69958fd1010682873c193afad0f5d93a4abb8f5ce728c0500fb43912b";
    rev = "523b6029eb4b8569504086dfb5b8538330e5f522";
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
