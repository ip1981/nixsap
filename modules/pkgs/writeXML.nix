{ writeTextFile, libxml2 }:

name: text:
  writeTextFile
  {
    inherit name text;
    checkPhase = ''
      ${libxml2.bin}/bin/xmllint \
        --format --noblanks --nocdata "$out" > linted
      mv linted "$out"
    '';
  }
