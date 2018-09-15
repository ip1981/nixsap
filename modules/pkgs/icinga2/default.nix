{ stdenv, fetchurl
, bison, boost, cmake, flex
, libedit, mariadb, postgresql
, openssl, yajl, pkgconfig
, makeWrapper
}:

stdenv.mkDerivation rec {
  version = "2.9.1";
  name = "icinga2-${version}";

  src = fetchurl {
    url = "https://github.com/Icinga/icinga2/archive/v${version}.tar.gz";
    sha256 = "0d6r72kcjdc9mn07dv5vrpkqncvcgaw7zwcqp6cim64fmkh1xh6v";
  };

  buildInputs = [
    bison boost cmake flex libedit makeWrapper mariadb.client openssl
    pkgconfig postgresql yajl
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

    rm -rvf \
      $out/icinga2/cache \
      $out/icinga2/etc/icinga2/features-enabled \
      $out/icinga2/etc/init.d \
      $out/icinga2/etc/logrotate.d \
      $out/icinga2/log \
      $out/icinga2/spool \
      $out/run \
      $out/share/doc/icinga2/markdown

    for s in $out/icinga2/etc/icinga2/scripts/* ; do
      substituteInPlace $s --replace /usr/bin/printf printf
    done

    wrapProgram $out/lib/icinga2/sbin/icinga2 \
      --prefix LD_LIBRARY_PATH : $out/lib/icinga2

    rm -vf $out/sbin/icinga2
    ln -svf $out/lib/icinga2/sbin/icinga2 $out/sbin/icinga2
    test -x $out/sbin/icinga2
  '';

  buildPhase = ''
    make VERBOSE=1
  '';
}
