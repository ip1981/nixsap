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
  version = "1.23.17";
  name = "mediawiki-${version}";

  src = let
    v = splitString "." version;
    minor = "${elemAt v 0}.${elemAt v 1}";
  in pkgs.fetchurl {
    url = "https://releases.wikimedia.org/mediawiki/${minor}/${name}.tar.gz";
    sha256 = "1fxymqirjj2sfbrgcgxig9k6ik5ndw9qq9qn91xm9cnpjksc079x";
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
      $MEDIAWIKI_LOCAL_SETTINGS = getenv('MEDIAWIKI_LOCAL_SETTINGS');
      if (isset($MEDIAWIKI_LOCAL_SETTINGS)) {
        require_once ($MEDIAWIKI_LOCAL_SETTINGS);
      };
    ?>
    EOF

    ${concatMapStrings (e: ''
      mv $out/extensions/${e} ''${${e}}
    '') bundled}
  '';
}
