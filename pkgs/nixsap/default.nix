{ stdenv, openssh, nix, makeWrapper }:

stdenv.mkDerivation {
  name = "nixsap";
  phases = [ "installPhase" ];
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin
    cp -a ${./nixsap.bash} $out/bin/nixsap
    chmod +x $out/bin/nixsap
    patchShebangs $out/bin/nixsap
    wrapProgram "$out/bin/nixsap" \
      --prefix PATH : '${openssh}/bin' \
      --prefix PATH : '${nix}/bin'
  '';
}

