{ stdenv, bash, mysql, makeWrapper }:

stdenv.mkDerivation {
  name = "rdsdump";
  buildInputs = [ bash ];
  phases = [ "installPhase" ];
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin
    cp -a ${./rdsdump.bash} $out/bin/rdsdump
    chmod +x $out/bin/rdsdump
    patchShebangs $out/bin/rdsdump
    wrapProgram "$out/bin/rdsdump" \
      --prefix PATH : '${mysql.client.bin}/bin'
  '';
}

