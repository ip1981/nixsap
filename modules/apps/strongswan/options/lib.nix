lib:

let
  inherit (lib) mkOption mkOptionType mergeOneOption elem flip concatStringsSep;
  inherit (lib.types) nullOr submodule bool either;

in rec {
  default = v: type: mkOption { type = type; default = v; };
  optional = type: mkOption { type = nullOr type; default = null; };
  set = opts: mkOption { type = nullOr (submodule { options = opts; }); default = null; };

  # XXX https://github.com/NixOS/nixpkgs/issues/9826
  enum' = values:
    let show = v: let t = builtins.typeOf v;
            in if t == "string" then ''"${v}"''
          else if t == "int" then builtins.toString v
          else ''<${t}>'';
    in mkOptionType {
      name = "one of ${concatStringsSep ", " (map show values)}";
      check = flip elem values;
      merge = mergeOneOption;
    };

  boolean = either bool (enum' [ "yes" "no" ]);
  boolOr = l: either bool (enum' ([ "yes" "no" ] ++ l));
}
