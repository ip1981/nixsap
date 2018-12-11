# Via openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -nodes
{ stdenv }:
stdenv.mkDerivation {
  name = "fakeSSL";
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out
    ln -sf ${./cert.pem} "$out/cert.pem"
    ln -sf ${./key.pem} "$out/key.pem"
  '';
}
