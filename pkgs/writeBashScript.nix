{ bash, writeScript, haskellPackages, runCommand }:

name: text:
let
  f = writeScript name ''
    #!${bash}/bin/bash
    ${text}
  '';
in
runCommand name { } ''
  ${haskellPackages.ShellCheck}/bin/shellcheck ${f}
  cp -a ${f} $out
''
