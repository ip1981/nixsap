{ fetchgit, python3Packages }:

python3Packages.buildPythonApplication rec {
  pname = "pyresttest";
  version = "1.7.1+git";

  src = fetchgit {
    url = "https://github.com/svanoort/pyresttest.git";
    rev = "f92acf8e838c4623ddd8e12e880f31046ff9317f";
    sha256 = "0zwizn57x7grvwrvz4ahdrabkgiadyffgf4sqnhdacpczxpry57r";
  };

  patches = [
    ./add-unix-socket.patch
  ];

  propagatedBuildInputs = with python3Packages; [
    future jmespath pycurl pyyaml
  ];

  doCheck = false;
}
