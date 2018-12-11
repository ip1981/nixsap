{ bash, writeTextFile, haskellPackages }:

let

  shellcheck = haskellPackages.ShellCheck;

in

name: text:
  writeTextFile
  {
    inherit name;
    executable = true;
    text = ''
      #!${bash}/bin/bash
      ${text}
    '';
    checkPhase = ''
      ${shellcheck}/bin/shellcheck "$out"
    '';
  }
