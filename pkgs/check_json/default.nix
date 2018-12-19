{ stdenv, pkgs, makeWrapper }:

stdenv.mkDerivation {
  name = "check_json";
  outputs = [ "out" "conf" ];
  unpackPhase = ":";
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin

    cp ${./check_json} $out/bin/check_json
    cp ${./check_json.conf} $conf

    chmod +x "$out/bin/"*

    substituteInPlace "$conf" \
      --replace check_json "$out/bin/check_json"

    wrapProgram "$out/bin/check_json" \
      --prefix PATH : "${pkgs.curl.bin}/bin:${pkgs.gnugrep}/bin:${pkgs.jq}/bin"
  '';
}
