{ pkgs }:

let

  inherit (builtins)
    attrNames fromJSON head readFile ;

  packages = fromJSON (readFile ./main.json);
  package = head packages;

  name = head (attrNames package);
  version = package.${name};

  main =
    let m = (import ./main.nix {
      inherit pkgs;
      inherit (pkgs) nodejs;
      inherit (pkgs.stdenv) system;
    });
    in m // {
      "${name}-${version}" = m."${name}-${version}".override (super: {
        # XXX: build bundled libsassl, DO NOT DOWNLOAD binaries!
        preRebuild = ''
          SASS_FORCE_BUILD=true npm run-script build
        '';
      });
    };


in
pkgs.runCommand "nodejs-sass-${version}" {}
''
  mkdir -p $out/bin
  ln -s ${main."${name}-${version}"}/lib/node_modules/node-sass/bin/node-sass \
    $out/bin/node-sass
  test -x $out/bin/node-sass
''
