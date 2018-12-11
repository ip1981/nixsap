strBase64:

let

  inherit (builtins)
    concatStringsSep genList stringLength substring trace ;

  base64 = {
    # n=0; for l in {A..Z} {a..z} {0..9} + /; do printf '"%s" = %2s; ' $l $n; (( n++ )); (( n % 8 )) || echo; done
    "A" =  0; "B" =  1; "C" =  2; "D" =  3; "E" =  4; "F" =  5; "G" =  6; "H" =  7;
    "I" =  8; "J" =  9; "K" = 10; "L" = 11; "M" = 12; "N" = 13; "O" = 14; "P" = 15;
    "Q" = 16; "R" = 17; "S" = 18; "T" = 19; "U" = 20; "V" = 21; "W" = 22; "X" = 23;
    "Y" = 24; "Z" = 25; "a" = 26; "b" = 27; "c" = 28; "d" = 29; "e" = 30; "f" = 31;
    "g" = 32; "h" = 33; "i" = 34; "j" = 35; "k" = 36; "l" = 37; "m" = 38; "n" = 39;
    "o" = 40; "p" = 41; "q" = 42; "r" = 43; "s" = 44; "t" = 45; "u" = 46; "v" = 47;
    "w" = 48; "x" = 49; "y" = 50; "z" = 51; "0" = 52; "1" = 53; "2" = 54; "3" = 55;
    "4" = 56; "5" = 57; "6" = 58; "7" = 59; "8" = 60; "9" = 61; "+" = 62; "/" = 63;
  };

  quartet_to_int24 = q:
    # https://en.wikipedia.org/wiki/Base64
    let
      s = n: assert (stringLength q == 4); substring (3 - n) 1 q;
      d = n: base64.${s n};
    in if s 0 != "=" then
        64 * (64 * (64 * (d 3) + (d 2)) + (d 1)) + (d 0)
      else if s 1 != "=" then
        64 * (64 * (64 * (d 3) + (d 2)) + (d 1)) / 256 # right shift by 8 bits
      else
        64 * (64 * (64 * (d 3) + (d 2))) / 65536 # right shift by 16 bits
      ;

  int24_to_hex = i: # 16777215 (0xFFFFFF, 2^24-1) max
    let
      hex = "0123456789abcdef";
      toHex = n:
        let
          d = n / 16;
          r = n - 16 * d;
        in "${if d != 0 then toHex d else ""}${substring r 1 hex}";
    in assert (0 <= i && i <= 16777215); toHex i;

  quartets = s:
    let
      l = stringLength s;
      h = substring 0 4 s;
      t = substring 4 (l - 4) s;
    in [h] ++ (if t != "" then quartets t else []);


  quartet_to_hex = q: # base64 quartet into hex with padding
    let
      i = quartet_to_int24 q;
      h = int24_to_hex i;
      s = if substring 2 1 q == "=" then 1
          else if substring 3 1 q == "=" then 2
          else 3; # number of bytes
      w = s * 2; # number of hexadecimal digits
      filler = concatStringsSep "" (genList (_: "0") (w - stringLength h));
    in "${filler}${h}";

/*

  FIXME: usage of library functions like concatMapString
  causes very cryptic errors:

  # nix-instantiate --eval --expr 'import ./fromBase64.nix "kjOzmCPxyw0bPciMsGSh5q+bT9g="' --show-trace
  error: while evaluating anonymous function at .../fromBase64.nix:1:1, called from (string):1:18:
  value is a function while a set was expected, at .../fromBase64.nix:3:4

*/

in concatStringsSep "" (map quartet_to_hex (quartets strBase64))

