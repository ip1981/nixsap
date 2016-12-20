{ mkDerivation, aeson, base, blaze-html, blaze-markup, bytestring
, data-default-class, directory, docopt, fast-logger, fetchgit
, filepath, http-types, interpolatedstring-perl6, mtl, network
, postgresql-simple, resource-pool, scotty, stdenv, text, unix, wai
, wai-extra, wai-middleware-static, warp
}:
mkDerivation {
  pname = "sproxy-web";
  version = "0.4.1";
  src = fetchgit {
    url = "https://github.com/zalora/sproxy-web.git";
    sha256 = "01cybqrbf2i6sfxibdmri8sicnhxzqdhmrngzmgz9vizffyf9fbd";
    rev = "5d7ee61deb55359ae8ce6013dd7fe81bcdc0f9a9";
  };
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
