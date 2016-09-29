{ stdenv, gnused }:

stdenv.mkDerivation {
  name = "check_systemd";
  src = ./check_systemd;
  outputs = [ "out" "conf" ];
  unpackPhase = ":";
  installPhase = ''
    mkdir -p $out/bin

    cp "$src" $out/bin/check_systemd

    substituteInPlace "$out/bin/"* \
      --replace sed '${gnused}/bin/sed'

    chmod +x "$out/bin/"*

    cat <<CONF > $conf
    object CheckCommand "systemd" {
      import "plugin-check-command"
      command = [ "$out/bin/check_systemd" ]
    }
    CONF
  '';
}
