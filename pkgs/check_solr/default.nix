{ stdenv, haskellPackages }:
let

  haskellPackage = haskellPackages.callPackage ./cabal2nix.nix {};

in stdenv.mkDerivation {
  name = "check-solr-${haskellPackage.version}";
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/bin
    cp -a ${haskellPackage}/bin/* $out/bin/
  '';
}
