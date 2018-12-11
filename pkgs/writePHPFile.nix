{ writeTextFile, php }:

name: text:
  writeTextFile
  {
    inherit name text;
    checkPhase = ''
      ${php}/bin/php -l "$out"
    '';
  }
