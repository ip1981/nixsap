{ mkDerivation, aeson, base, bytestring, ConfigFile
, data-default-class, docopt, fast-logger, filepath, http-types
, interpolatedstring-perl6, MissingH, mtl, mysql, mysql-simple
, network, resource-pool, scotty, stdenv, text, unix
, unordered-containers, wai, wai-extra, wai-middleware-static, warp
}:
mkDerivation {
  pname = "mywatch";
  version = "0.3.0";
  sha256 = "1a7fqyn0pvnbxzn9fiaib4pj7hq5p2qgnbdwryg70lkgnjm4y0h4";
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson base bytestring ConfigFile data-default-class docopt
    fast-logger filepath http-types interpolatedstring-perl6 MissingH
    mtl mysql mysql-simple network resource-pool scotty text unix
    unordered-containers wai wai-extra wai-middleware-static warp
  ];
  description = "Web application to view and kill MySQL queries";
  license = stdenv.lib.licenses.mit;
}
