{ stdenv, fetchurl
, bison, boost, cmake, flex
, libedit, mariadb, postgresql
, openssl, yajl, pkgconfig
}:

stdenv.mkDerivation rec {
  version = "2.8.2";
  name = "icinga2-${version}";

  src = fetchurl {
    url = "https://github.com/Icinga/icinga2/archive/v${version}.tar.gz";
    sha256 = "070mj6jg3jkzybwhs6v2g3hhfq34dfqhxs8nlqbn3446bj82122h";
  };

  buildInputs = [
    bison boost cmake flex libedit mariadb.client openssl pkgconfig
    postgresql yajl
  ];

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
    "-DMYSQL_INCLUDE_DIR=${mariadb.client.dev}/include/mysql"
  ];

  # XXX Without DESTDIR it tries to write to /icinga2 and /run:
  installPhase = ''
    rm -rf tmp
    mkdir -p tmp
    make install DESTDIR=$(pwd)/tmp
    mv -v tmp/$out $out
    mv -v tmp/icinga2 $out/icinga2
    rm -rvf $out/run
    for s in $out/icinga2/etc/icinga2/scripts/* ; do
      substituteInPlace $s --replace /usr/bin/printf printf
    done
    rm -vf $out/sbin/icinga2
    ln -svf $out/lib/icinga2/sbin/icinga2 $out/sbin/icinga2
    test -x $out/sbin/icinga2
  '';

  buildPhase = ''
    make VERBOSE=1
  '';
}
