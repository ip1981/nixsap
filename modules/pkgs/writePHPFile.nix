{ php, writeText, runCommand }:

name: text:
let
  f = writeText name text;
in
runCommand name { } ''
  ${php}/bin/php -l '${f}'
  cp -a '${f}' $out
''
