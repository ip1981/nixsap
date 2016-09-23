{ lib, pkgs }:

let
  inherit (builtins) elemAt;
  inherit (lib) splitString concatMapStrings;

  bundled = [
    "Cite" "ConfirmEdit" "Gadgets" "ImageMap" "InputBox" "Interwiki"
    "LocalisationUpdate" "Nuke" "ParserFunctions" "PdfHandler" "Poem"
    "Renameuser" "SpamBlacklist" "SyntaxHighlight_GeSHi" "TitleBlacklist"
    "WikiEditor"
  ];

in pkgs.stdenv.mkDerivation rec {
  version = "1.23.13";
  name = "mediawiki-${version}";

  src = let
    v = splitString "." version;
    minor = "${elemAt v 0}.${elemAt v 1}";
  in pkgs.fetchurl {
    url = "https://releases.wikimedia.org/mediawiki/${minor}/${name}.tar.gz";
    sha256 = "168wpf53n4ksj2g5q5r0hxapx6238dvsfng5ff9ixk6axsn0j5d0";
  };

  patches = [
    ./T122487.patch
    ./file-backend-default-mode.patch
  ];

  outputs = [ "out" ] ++ bundled;

  installPhase = ''
    cp -a . $out

    rm -rf $out/tests
    rm -rf $out/mw-config
    rm -rf $out/maintenance/dev
    rm -rf $out/maintenance/hiphop

    sed -i \
    -e 's|/bin/bash|${pkgs.bash}/bin/bash|g' \
    -e 's|/usr/bin/timeout|${pkgs.coreutils}/bin/timeout|g' \
      $out/includes/limit.sh \
      $out/includes/GlobalFunctions.php

    cat <<'EOF' > $out/LocalSettings.php
    <?php
      if (isset($_ENV['MEDIAWIKI_LOCAL_SETTINGS'])) {
        require_once ($_ENV['MEDIAWIKI_LOCAL_SETTINGS']);
      };
    ?>
    EOF

    ${concatMapStrings (e: ''
      mv $out/extensions/${e} ''${${e}}
    '') bundled}
  '';
}
