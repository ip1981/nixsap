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
  version = "1.93.0";
  src = fetchgit {
    url = "https://github.com/ip1981/sproxy2.git";
    sha256 = "0kg3904v3ij5l6qlal4yqd4412dxk73jn0gqsxdajxai6n8qmypv";
    rev = "cfda358dfd234edf5af50fd052187ab0e464b2f5";
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
