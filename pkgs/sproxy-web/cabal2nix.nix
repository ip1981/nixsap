{ mkDerivation, aeson, base, blaze-html, blaze-markup, bytestring
, data-default-class, directory, docopt, fast-logger, filepath
, http-types, interpolatedstring-perl6, mtl, network
, postgresql-simple, resource-pool, scotty, stdenv, text, unix, wai
, wai-extra, wai-middleware-static, warp
}:
mkDerivation {
  pname = "sproxy-web";
  version = "0.4.1";
  sha256 = "0jvkvk5yqp4gibg61q67iczaqvfszikxvvgf04fg6xs23gjkpihp";
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson base blaze-html blaze-markup bytestring data-default-class
    directory docopt fast-logger filepath http-types
    interpolatedstring-perl6 mtl network postgresql-simple
    resource-pool scotty text unix wai wai-extra wai-middleware-static
    warp
  ];
  description = "Web interface to sproxy database";
  license = stdenv.lib.licenses.mit;
}
