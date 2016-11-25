{ mkDerivation, aeson, base, base64-bytestring, blaze-builder
, bytestring, cereal, conduit, containers, cookie, docopt, entropy
, fetchgit, Glob, http-client, http-conduit, http-types
, interpolatedstring-perl6, network, postgresql-simple
, resource-pool, SHA, sqlite-simple, stdenv, text, time, unix
, unordered-containers, wai, wai-conduit, warp, warp-tls, word8
, yaml
}:
mkDerivation {
  pname = "sproxy2";
  version = "1.90.2";
  src = fetchgit {
    url = "https://github.com/ip1981/sproxy2.git";
    sha256 = "02hj4bxgkvvd1sbifj8a8nyih37lr7zgdkswp54hf41nqvwa5zwh";
    rev = "33ab0b2f945b8f4995f77c3246eb3c3f1b9d6df4";
  };
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson base base64-bytestring blaze-builder bytestring cereal
    conduit containers cookie docopt entropy Glob http-client
    http-conduit http-types interpolatedstring-perl6 network
    postgresql-simple resource-pool SHA sqlite-simple text time unix
    unordered-containers wai wai-conduit warp warp-tls word8 yaml
  ];
  description = "Secure HTTP proxy for authenticating users via OAuth2";
  license = stdenv.lib.licenses.mit;
}
