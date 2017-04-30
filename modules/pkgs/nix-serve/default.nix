{ stdenv, coreutils, pxz, nix, perl, perlPackages }:

let
  inherit (stdenv.lib)
    makeBinPath
    ;

in stdenv.mkDerivation {
  name = "nix-serve";

  src = "${./nix-serve.psgi}";

  buildInputs = [ pxz perl nix ]
    ++ (with perlPackages; [ DBI DBDSQLite Plack Starman ]);

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/libexec/nix-serve
    perl -c "$src"
    cat "$src" > "$out/libexec/nix-serve.psgi"

    mkdir -p $out/bin
    cat > $out/bin/nix-serve <<EOF
    #! ${stdenv.shell}
    export PATH=${makeBinPath [ coreutils pxz nix ]}:\$PATH
    export PERL5LIB=$PERL5LIB
    exec ${perlPackages.Starman}/bin/starman "$out/libexec/nix-serve.psgi" "\$@"
    EOF
    chmod +x $out/bin/nix-serve
  '';
}
