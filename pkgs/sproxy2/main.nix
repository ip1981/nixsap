{ mkDerivation, aeson, base, base64-bytestring, blaze-builder
, bytestring, cereal, conduit, cookie, docopt, entropy, Glob
, http-client, http-conduit, http-types, interpolatedstring-perl6
, network, postgresql-simple, resource-pool, SHA, sqlite-simple
, stdenv, text, time, unix, unordered-containers, wai, wai-conduit
, warp, warp-tls, word8, yaml
}:
mkDerivation {
  pname = "sproxy2";
  version = "1.97.0";
  sha256 = "538a95dd0714981ba255ded73d634f459739eaec04a44426ef86d015c8d2c8c6";
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson base base64-bytestring blaze-builder bytestring cereal
    conduit cookie docopt entropy Glob http-client http-conduit
    http-types interpolatedstring-perl6 network postgresql-simple
    resource-pool SHA sqlite-simple text time unix unordered-containers
    wai wai-conduit warp warp-tls word8 yaml
  ];
  description = "Secure HTTP proxy for authenticating users via OAuth2";
  license = stdenv.lib.licenses.mit;
}
