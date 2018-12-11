{ writeTextFile, pythonPackages }:

let

  yamllint = pythonPackages.yamllint;

in

name: text:
  writeTextFile
  {
    inherit name text;
    checkPhase = ''
      ${yamllint}/bin/yamllint "$out"
    '';
  }
