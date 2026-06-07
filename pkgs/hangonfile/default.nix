{ gcc, runCommand, ... }:
let
  cc = "${gcc}/bin/gcc -Wall -Wextra -Werror -O2";
in runCommand "hangonfile" {} "${cc} -o $out ${./hangonfile.c}"

