{ gcc, runCommand, ... }:
let
  cc = "${gcc}/bin/gcc -Wall -Wextra -Werror -O2";
in runCommand "wait4file" {} "${cc} -o $out ${./wait4file.c}"

