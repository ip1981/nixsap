{ stdenv, pkgs, fetchurl, python27Packages }:
let

  rev = "7f4a9852a0e470698d90afc0036d2738a4906477";

  pmp-check-aws-rds = stdenv.mkDerivation rec {
    name = "pmp-check-aws-rds";
    src = fetchurl {
      url = "https://raw.githubusercontent.com/percona/percona-monitoring-plugins/${rev}/nagios/bin/pmp-check-aws-rds.py";
      sha256 = "1ps7ag2hmbbzg3w6h76l6j4ijigfhlvmirj8h7v9qyrdcgzlsjma";
    };

    buildInputs = with python27Packages; [ python wrapPython ];
    pythonPath = with python27Packages; [ boto ];
    phases = [ "installPhase" "fixupPhase" ];

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/${name}
      chmod +x $out/bin/${name}
      wrapPythonPrograms
    '';

  };

in stdenv.mkDerivation {
  name = "check_aws_rds";
  outputs = [ "out" "conf" ];

  phases = [ "installPhase" "fixupPhase" ];
  nativeBuildInputs = with pkgs; [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin

    cp ${./check_aws_rds} $out/bin/check_aws_rds
    cp ${./check_aws_rds.conf} $conf

    chmod +x "$out/bin/"*

    substituteInPlace "$conf" \
      --replace check_aws_rds "$out/bin/check_aws_rds"

    wrapProgram "$out/bin/check_aws_rds" \
      --prefix PATH : "${pmp-check-aws-rds}/bin:${pkgs.bind.dnsutils}/bin"
  '';
}
