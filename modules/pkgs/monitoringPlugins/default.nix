{ stdenv, fetchurl, pkgs }:

stdenv.mkDerivation rec {
  version = "2.2";
  name = "monitoring-plugins-${version}";
  src = fetchurl {
    url = "https://github.com/monitoring-plugins/monitoring-plugins/archive/v${version}.tar.gz";
    sha256 = "0nq0ilnfmwka5ds9k3bkgqd9238cv1yfyik8xhqbvnkpc3nh1cfk";
  };

  buildInputs = with pkgs; [
    autoreconfHook bind.dnsutils fping libdbi libtap mariadb.lib openldap.dev
    openssh openssl.dev perl postgresql procps smbclient sudo
  ];

  doCheck = false; # tests are broken badly

  patches = [
    ./mysql_check_slave.patch
    ./test-str-format.patch
  ];

  configurePhase = ''
    ./configure \
      --prefix=$out \
      --disable-nls \
      --with-ping-command="/run/wrappers/bin/ping -n -U -w %d -c %d %s" \
      --with-ping6-command="/run/wrappers/bin/ping6 -n -U -w %d -c %d %s" \
      --with-trusted-path=/run/wrappers/bin:/run/current-system/sw/bin:/usr/bin
  '';
}
