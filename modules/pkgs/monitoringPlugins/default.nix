{ stdenv, fetchurl
, autoreconfHook
, procps, perl
, fping, openssh, bind
, mariadb
, openssl
}:

stdenv.mkDerivation rec {
  version = "2.1.2";
  name = "monitoring-plugins-${version}";
  src = fetchurl {
    url = "https://github.com/monitoring-plugins/monitoring-plugins/archive/v${version}.tar.gz";
    sha256 = "0mgs59326yzvx92pdqmn671d40czixd7k60dvsbz89ah2r96vps7";
  };

  buildInputs = [
    autoreconfHook
    procps perl
    fping openssh bind
    mariadb.lib
    openssl
  ];

  patches = [
    ./mysql_check_slave.patch
  ];

  configurePhase = ''
    ./configure \
      --prefix=$out \
      --disable-nls \
      --with-ping-command="/var/setuid-wrappers/ping -n -U -w %d -c %d %s" \
      --with-ping6-command="/var/setuid-wrappers/ping6 -n -U -w %d -c %d %s" \
      --with-trusted-path=/var/setuid-wrappers:/run/current-system/sw/bin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin
  '';
}
