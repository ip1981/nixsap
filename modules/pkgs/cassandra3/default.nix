{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  version = "3.11";
  name = "cassandra-${version}";

  src = pkgs.fetchgit {
    url = "https://git-wip-us.apache.org/repos/asf/cassandra.git";
    rev = "30412b08c0eb4a5cc5296725c7359f2741483ea2";
    sha256 = "0a5xgsgd5a91qckh4i40bxa6w9fw4bry0cqa3aj2hc7friwj199s";
  };

  buildInputs = with pkgs; [ ant jdk ];

  patches = [
  ];

  configurePhase = ''
    rm -rfv lib/*sigar*
    cp --symbolic-link -fv ${pkgs.hyperic-sigar}/share/java/* lib/
  '';

  buildPhase = ''
    ant jar
  '';

  installPhase = ''
    mkdir -p $out/lib/jni
    mkdir -p $out/share/java

    cp -v lib/*.jar $out/share/java/
    cp -v lib/*.zip $out/share/java/
    cp -v build/apache-cassandra*.jar $out/share/java/

    cp --symbolic-link -fv ${pkgs.hyperic-sigar}/share/java/* $out/share/java/
    cp --symbolic-link -fv ${pkgs.hyperic-sigar}/lib/jni/* $out/lib/jni/

  '';
}
