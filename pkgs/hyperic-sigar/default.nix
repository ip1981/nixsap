{ stdenv, fetchurl, ant, jdk, perl }:

stdenv.mkDerivation rec {
  name = "hyperic-sigar-${version}";
  version = "1.6.4";

  src = fetchurl {
    url = "https://github.com/hyperic/sigar/archive/sigar-${version}.tar.gz";
    sha256 = "0bh5l1wzmv464v3np5zjb59d7i0vbk9ciy71683fa43yxg0h96qp";
  };

  nativeBuildInputs = [ ant jdk perl ];
  buildInputs = [ ];

  configurePhase = ":";

  buildPhase = ''
    cd bindings/java
    ant build
  '';

  installPhase = ''
    mkdir -p $out/{lib/jni,share/java}
    cp sigar-bin/lib/sigar.jar $out/share/java/
    cp sigar-bin/lib/libsigar-* $out/lib/jni/
  '';

  meta = with stdenv.lib; {
    description = "System Information Gatherer And Reporter";
    license = licenses.asl20;
    platforms = platforms.unix;
  };
}

