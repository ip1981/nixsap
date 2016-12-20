{ mkDerivation, aeson, base, base64-bytestring, bytestring, docopt
, fetchgit, HTTP, http-conduit, nagios-check, raw-strings-qq
, regex-tdfa, scientific, stdenv, text, unordered-containers
}:
mkDerivation {
  pname = "check-solr";
  version = "0.1.0";
  src = fetchgit {
    url = "https://github.com/ip1981/check-solr.git";
    sha256 = "0hama3kglnn4kyzkssl1llb61kcgyhynpbbk6xsf015hvi90hsa0";
    rev = "869c945fb56f0ff187125ee352a6876002eba596";
  };
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson base base64-bytestring bytestring docopt HTTP http-conduit
    nagios-check raw-strings-qq regex-tdfa scientific text
    unordered-containers
  ];
  executableHaskellDepends = [ base docopt raw-strings-qq ];
  description = "Icinga / Nagios plugin for Solr";
  license = stdenv.lib.licenses.mit;
}
