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
  version = "1.90.0";
  src = fetchgit {
    url = "https://github.com/ip1981/sproxy2.git";
    sha256 = "1dpdaparvrd3ykwpac99wqfsnywqvbvscdj7j3v2xyc1sa4vbkda";
    rev = "4a9f329a6ea9bfa03352ca0d9dd1d556b93bec36";
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
