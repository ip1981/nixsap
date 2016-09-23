{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  version = "2.6.1";
  name = "mathjax-${version}";

  src = fetchurl {
    url = "https://github.com/mathjax/MathJax/archive/${version}.tar.gz";
    sha256 = "1f7v48s7km9fi9i0bignn8f91z3bk04n4jx407l3xsd4hxfr8in7";
  };

  installPhase = ''
    mkdir -p $out
    cp -a * $out/
    rm -rf $out/unpacked
    rm -rf "$out/"*.json
  '';
}
