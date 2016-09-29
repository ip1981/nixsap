{ mkDerivation, aeson, attoparsec, base, base64-bytestring
, bytestring, containers, data-default, docopt, entropy, fetchgit
, http-conduit, http-kit, http-types, interpolatedstring-perl6
, network, postgresql-simple, resource-pool, SHA, split, stdenv
, text, time, tls, unix, utf8-string, x509, yaml
}:
mkDerivation {
  pname = "sproxy";
  version = "0.9.8";
  src = fetchgit {
    url = "https://github.com/zalora/sproxy.git";
    sha256 = "40d86e00cfbdc96033ca53e773a7467cd3e2206856d27e4a24076d9449c46ca7";
    rev = "507a0984d4ce01ef0d83e7cda37cba5c80a33b75";
  };
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson attoparsec base base64-bytestring bytestring containers
    data-default docopt entropy http-conduit http-kit http-types
    interpolatedstring-perl6 network postgresql-simple resource-pool
    SHA split text time tls unix utf8-string x509 yaml
  ];
  description = "HTTP proxy for authenticating users via OAuth2";
  license = stdenv.lib.licenses.mit;
}
