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
  version = "1.90.1";
  src = fetchgit {
    url = "https://github.com/ip1981/sproxy2.git";
    sha256 = "1vxacv58xl7k4y71v04icjs8l810ln0g885bf1km4pkz404vxx6v";
    rev = "7578b8d710c235c1b8c1fc76e2e37e4eb46d89d5";
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
