{ mkDerivation, aeson, base, base64-bytestring, blaze-builder
, bytestring, cereal, conduit, cookie, docopt, entropy, Glob
, http-client, http-conduit, http-types, interpolatedstring-perl6
, network, postgresql-simple, resource-pool, SHA, sqlite-simple
, stdenv, text, time, unix, unordered-containers, wai, wai-conduit
, warp, warp-tls, word8, yaml
}:
mkDerivation {
  pname = "sproxy2";
  version = "1.97.1";
  sha256 = "a43358ca9ebba23b121d74a1388926ed33c016636b00098ce749825b17a673e5";
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
