{ stdenv, fetchurl
, bison, boost, cmake, flex
, libedit, mysql, openssl, yajl
}:

stdenv.mkDerivation rec {
  version = "2.4.10";
  name = "icinga2-${version}";

  src = fetchurl {
    url = "https://github.com/Icinga/icinga2/archive/v${version}.tar.gz";
    sha256 = "0pj2y24kgf17106903lnz9gmp5hb3irhafq8sp22qf1wa0q395n2";
  };

  buildInputs = [ bison boost cmake flex libedit openssl yajl ];

  patches = [
    ./check_mysql_slave.patch
  ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_LOCALSTATEDIR=/icinga2"
    "-DCMAKE_INSTALL_SYSCONFDIR=/icinga2/etc" # this will need runtime support
    "-DICINGA2_COMMAND_GROUP=icingacmd"
    "-DICINGA2_GROUP=icinga"
    "-DICINGA2_RUNDIR=/run"
    "-DICINGA2_USER=icinga"
    "-DICINGA2_WITH_PGSQL=OFF"
    "-DMYSQL_INCLUDE_DIR=${mysql.lib}/include/mysql"
    "-DMYSQL_LIB_DIR=${mysql.lib}/lib"
  ];

  # XXX Without DESTDIR it tries to write to /icinga2 and /run:
  installPhase = ''
    rm -rf tmp
    mkdir -p tmp
    make install DESTDIR=$(pwd)/tmp
    mv tmp/$out $out
    mv tmp/icinga2 $out/icinga2
    rm -rf $out/run
    for s in $out/icinga2/etc/icinga2/scripts/* ; do
      substituteInPlace $s --replace /usr/bin/printf printf
    done
  '';
}
