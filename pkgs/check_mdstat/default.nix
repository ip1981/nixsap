{ stdenv, gawk, gnugrep }:

stdenv.mkDerivation {
  name = "check_mdstat";
  src = ./check_mdstat;
  outputs = [ "out" "conf" ];
  unpackPhase = ":";
  installPhase = ''
    mkdir -p $out/bin

    cp "$src" $out/bin/check_mdstat

    substituteInPlace "$out/bin/"* \
      --replace awk '${gawk}/bin/awk' \
      --replace grep '${gnugrep}/bin/grep'

    chmod +x "$out/bin/"*

    cat <<CONF > $conf
    object CheckCommand "mdstat" {
      import "plugin-check-command"
      command = [ "$out/bin/check_mdstat" ]
    }
    CONF
  '';
}
