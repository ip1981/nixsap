{ stdenv, fetchurl
, php
}:

stdenv.mkDerivation rec {
  version = "2.5.3";
  name = "icingaweb2-${version}";

  src = fetchurl {
    url = "https://github.com/Icinga/icingaweb2/archive/v${version}.tar.gz";
    sha256 = "14k5rn09v2ww71x6d8p9rh980nwsmwan2gff0b82dvcmb02576fs";
  };

  patches = [
    ./sproxy.patch
    ./php72.patch
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
