{ stdenv, pkgs, makeWrapper }:

stdenv.mkDerivation {
  name = "check_aws_s3_file";
  outputs = [ "out" "conf" ];
  unpackPhase = ":";
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin

    cp ${./check_aws_s3_file} $out/bin/check_aws_s3_file
    cp ${./check_aws_s3_file.conf} $conf

    chmod +x "$out/bin/"*

    substituteInPlace "$conf" \
      --replace check_aws_s3_file "$out/bin/check_aws_s3_file"

    wrapProgram "$out/bin/check_aws_s3_file" \
      --prefix PATH : "${pkgs.awscli}/bin:${pkgs.gnugrep}/bin:${pkgs.jq}/bin"
  '';
}
