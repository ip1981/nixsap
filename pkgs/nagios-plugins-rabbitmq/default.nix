{ fetchurl
, makeWrapper
, perl
, perlPackages
, stdenv
}:

stdenv.mkDerivation rec {
  version = "2.0.3";
  name = "nagios-plugins-rabbitmq-${version}";

  src = fetchurl {
    url = "https://github.com/nagios-plugins-rabbitmq/nagios-plugins-rabbitmq/archive/${version}.tar.gz";
    sha256 = "1fw40hzvb8sk5ss0hvrgv338lr019d2q9cc9ayy4hvk1c5bh3ljb";
  };

  buildInputs = [
    makeWrapper
    perl
    perlPackages.JSON
    perlPackages.LWPUserAgent
    perlPackages.ModuleBuild
    perlPackages.MonitoringPlugin
    perlPackages.URI
  ];

  buildPhase = "perl Build.PL --prefix=$out; ./Build build";
  installPhase = ''
    ./Build install

    for n in "$out/bin/"*; do
      wrapProgram "$n" --prefix PERL5LIB : "$PERL5LIB"
    done
  '';
}

