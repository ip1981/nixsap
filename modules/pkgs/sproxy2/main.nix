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
  version = "1.92.0";
  src = fetchgit {
    url = "https://github.com/ip1981/sproxy2.git";
    sha256 = "0hjgbzlff9ynmwh0w838ss7y0cvliv64pf3xhgxclm9dz82pscqb";
    rev = "18a47f502b5e3298cae41eab7378b2e72b4e8a4b";
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
