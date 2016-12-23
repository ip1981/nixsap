{ stdenv, fetchurl
, php
}:

stdenv.mkDerivation rec {
  version = "2.4.0";
  name = "icingaweb2-${version}";

  src = fetchurl {
    url = "https://github.com/Icinga/icingaweb2/archive/v${version}.tar.gz";
    sha256 = "15kn0sm4dcpm6hcpbinas2dvbz2ln2frrcsw0i3acnk51qm1p35a";
  };

  patches = [ ./sproxy.patch ];

  buildPhase = "true";

  installPhase = ''
    mkdir -p $out
    cp -a * $out
    rm -rf $out/.puppet
    rm -rf $out/Vagrantfile
    rm -rf $out/icingaweb2.spec
    rm -rf $out/modules/doc
    rm -rf $out/modules/iframe
    rm -rf $out/modules/setup
    rm -rf $out/modules/test
    rm -rf $out/packages
    rm -rf $out/test
  '';
}
