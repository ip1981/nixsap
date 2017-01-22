{ mkDerivation, aeson, base, bytestring, ConfigFile
, data-default-class, docopt, fast-logger, http-types
, interpolatedstring-perl6, MissingH, mtl, mysql, mysql-simple
, network, resource-pool, scotty, stdenv, text, unix
, unordered-containers, wai, wai-extra, wai-middleware-static, warp
}:
mkDerivation {
  pname = "mywatch";
  version = "0.2.1";
  sha256 = "1yi19mj1hqxym7baf524sf5ih3w1csmvy65izq10xdk5lalkpkzh";
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
