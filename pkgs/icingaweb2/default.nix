{ stdenv, fetchurl
, php
}:

stdenv.mkDerivation rec {
  version = "2.6.0";
  name = "icingaweb2-${version}";

  src = fetchurl {
    url = "https://github.com/Icinga/icingaweb2/archive/v${version}.tar.gz";
    sha256 = "1m0gi8zbrag4jwdcqicq5bb3s07z7kz0fg41a22cbqlgx6adivaa";
  };

  patches = [
    ./sproxy.patch
  ];

  buildPhase = "true";

  installPhase = ''
    mkdir -p $out
    cp -a * $out

    cd $out
    rm -rvf \
        .??* \
        Vagrantfile \
        icingaweb2.spec \
        modules/doc \
        modules/setup \
        modules/test \
        modules/translation \
        packages \
        test
  '';
}
