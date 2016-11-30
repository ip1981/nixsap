{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  name = "kibana-${version}.tar.xz";
  version = "5.0.2";

  # JS is a realm of sorrow. node2nix, npm2nix failed to package kibana
  # mostly because of npm and its registry being dumb beasts.
  # Instead, we are loading prebuild package. It's arch-dependent
  # only for bundled Node.JS binary (sic!). We remove it, and use our own.
  # This also makes it easier to patch the whole thing when needed.
  # Even worse: kibana can't run from a read-only directory.
  # So we will keep it in a tarball and extract before running.
  # Essentially it's like Java's WAR archives.
  src = fetchurl {
    url = "https://artifacts.elastic.co/downloads/kibana/kibana-${version}-linux-x86_64.tar.gz";
    sha1 = "c68eb5d3397a0afb7132630f120b1d53724a2fd9";
  };

  phases = [ "unpackPhase" "installPhase" ];

  installPhase = ''
    rm -r node bin
    tar cJf $out --transform 's,^,kibana-${version}/,' *
  '';

  meta = {
    description = "Visualize logs and time-stamped data";
    homepage = http://www.elasticsearch.org/overview/kibana;
    license = stdenv.lib.licenses.asl20;
  };
}
