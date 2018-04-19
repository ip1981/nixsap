{ stdenv, fetchurl
, php
}:

stdenv.mkDerivation rec {
  version = "2.5.1";
  name = "icingaweb2-${version}";

  src = fetchurl {
    url = "https://github.com/Icinga/icingaweb2/archive/v${version}.tar.gz";
    sha256 = "047s43amqj0i4k4xfac3n0784yvzphv3b9kirr4wycvn9pcz06d4";
  };

  patches = [ ./sproxy.patch ];

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
