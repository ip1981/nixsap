{ writeText, runCommand, libxml2 }:

name: text:
  let
    f = writeText "${name}.raw" text;
  in
  runCommand name { } ''
    ${libxml2}/bin/xmllint \
      --format --noblanks --nocdata ${f} \
        > $out
  ''
