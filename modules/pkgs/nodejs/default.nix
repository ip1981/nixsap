{ fetchurl, http-parser, libuv, openssl, python, stdenv,
  utillinux, v8, which, zlib }:

let

  deps = {
    inherit openssl zlib libuv http-parser;
  };

  sharedConfigureFlags = name: [
    "--shared-${name}"
    "--shared-${name}-includes=${builtins.getAttr name deps}/include"
    "--shared-${name}-libpath=${builtins.getAttr name deps}/lib"
  ];

  inherit (stdenv.lib) concatMap licenses ;

in stdenv.mkDerivation rec {

  version = "6.9.1";
  name = "nodejs-${version}";

  src = fetchurl {
    url = "https://nodejs.org/download/release/v${version}/node-v${version}.tar.xz";
    sha256 = "0a87vzb33xdg8w0xi3c605hfav3c9m4ylab1436whz3p0l9qvp8b";
  };

  configureFlags = concatMap sharedConfigureFlags (builtins.attrNames deps) ++ [ "--without-dtrace" ];
  dontDisableStatic = true;

  postInstall = ''
    PATH=$out/bin:$PATH patchShebangs $out
  '';

  buildInputs = 
    [ http-parser libuv openssl python utillinux which
      zlib ];

  setupHook = builtins.toFile "nodejs-setup-hook" ''
    addNodePath () {
        addToSearchPath NODE_PATH $1/lib/node_modules
    }

    envHooks+=(addNodePath)
  '';

  enableParallelBuilding = true;

  passthru.interpreterName = "nodejs";

  meta = {
    description = "Event-driven I/O framework for the V8 JavaScript engine";
    homepage = http://nodejs.org;
    license = licenses.mit;
  };
}

