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
        # XXX --nodedir is to prevent gyp from downloading nodejs headers
        # XXX: ref. https://github.com/nodejs/node-gyp/issues/1133
        preRebuild = ''
          npm run build --nodedir=${pkgs.nodejs}
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
