{ stdenv, pkgs, fetchurl, python27Packages }:
let

  rev = "556191f6d775f0505fb142c02f13a60ba7829ed9";

  pmp-check-aws-rds = stdenv.mkDerivation rec {
    name = "pmp-check-aws-rds";
    src = fetchurl {
      url = "https://raw.githubusercontent.com/percona/percona-monitoring-plugins/${rev}/nagios/bin/pmp-check-aws-rds.py";
      sha256 = "0ghq6nl2529llxz1icf5hyg75k2hjzdkzfwgrs0d69r3f62w4q5y";
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
  unpackPhase = ":";
  installPhase = ''
    mkdir -p $out/bin

    cp ${./check_aws_rds} $out/bin/check_aws_rds
    cp ${./check_aws_rds.conf} $conf

    substituteInPlace "$out/bin/"* \
      --replace pmp-check-aws-rds '${pmp-check-aws-rds}/bin/pmp-check-aws-rds' \
      --replace dig '${pkgs.bind}/bin/dig'

    substituteInPlace "$conf" \
      --replace check_aws_rds "$out/bin/check_aws_rds"

    chmod +x "$out/bin/"*

  '';
}
