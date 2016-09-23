{ stdenv, fetchbzr
, cmake, glib, mysql, openssl
, pcre, pkgconfig, zlib
}:

stdenv.mkDerivation rec {
  version = "0.9.2";
  name = "mydumper-${version}";

  src = fetchbzr {
    url = "lp:mydumper";
    rev = 188;
    sha256 = "0kbhgbh6mqkxwbs5yd20s1k3h3f3jqp2i041dhmlrnzl6irgqbg5";
  };

  buildInputs = [ cmake glib mysql.lib openssl pcre pkgconfig zlib ];
}
