{ stdenv, fetchurl
, php
}:

stdenv.mkDerivation rec {
  version = "2.3.4";
  name = "icingaweb2-${version}";

  src = fetchurl {
    url = "https://github.com/Icinga/icingaweb2/archive/v${version}.tar.gz";
    sha256 = "0kmxvwbr7g6daj2mqabzvmw3910igd85wrzwilkz83fizgmrszh5";
  };

  buildInputs = [ php ];

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
