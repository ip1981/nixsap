{ stdenv, bash, ... }:

stdenv.mkDerivation {
  name = "rdsdump";
  buildInputs = [ bash ];
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/bin
    cp -a ${./rdsdump.bash} $out/bin/rdsdump
    chmod +x $out/bin/rdsdump
    patchShebangs $out/bin/rdsdump
  '';
}

