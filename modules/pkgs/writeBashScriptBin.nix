{ writeBashScript, runCommand }:

name: text:
runCommand name { } ''
  mkdir -p $out/bin
  cp -a ${writeBashScript name text} $out/bin/${name}
''
