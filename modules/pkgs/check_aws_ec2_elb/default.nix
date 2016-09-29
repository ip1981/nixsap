{ stdenv, pkgs, makeWrapper }:

stdenv.mkDerivation {
  name = "check_aws_ec2_elb";
  outputs = [ "out" "conf" ];
  unpackPhase = ":";
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin

    cp ${./check_aws_ec2_elb} $out/bin/check_aws_ec2_elb
    cp ${./check_aws_ec2_elb.conf} $conf

    chmod +x "$out/bin/"*

    substituteInPlace "$conf" \
      --replace check_aws_ec2_elb "$out/bin/check_aws_ec2_elb"

    wrapProgram "$out/bin/check_aws_ec2_elb" \
      --prefix PATH : "${pkgs.awscli}/bin:${pkgs.gnused}/bin:${pkgs.jq}/bin:${pkgs.bind}/bin"
  '';
}
