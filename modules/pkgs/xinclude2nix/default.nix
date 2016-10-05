{ runCommand, haskellPackages }:

/*
  Given a list of XML files, produces a Nix file with a list of files included
  with the XInclude mechanism.  The file produced can be imported into other
  Nix files.  This requires read-write mode of evaluation.

  Use case: XML config files with portions of sensitive data (secrets, keys),
  merged in runtime. With this package, deployment tools like NixOps can be
  taught to extract keys and deploy them automatically.


  Example of input file (for Jenkins):

  <?xml version="1.0" encoding="UTF-8"?>
  <hudson xmlns:xi="http://www.w3.org/2001/XInclude">
    <useSecurity>true</useSecurity>
    <authorizationStrategy class="hudson.security.ProjectMatrixAuthorizationStrategy">
      <permission>hudson.model.Hudson.Read:ip1981</permission>
      <permission>hudson.model.Item.Build:ip1981</permission>
      <permission>hudson.model.Item.Cancel:ip1981</permission>
      <permission>hudson.model.Item.Read:ip1981</permission>
      <permission>hudson.model.Hudson.Administer:ip1981</permission>
    </authorizationStrategy>
    <securityRealm class="org.jenkinsci.plugins.GithubSecurityRealm">
      <clientID>XXXXXXXXXXXXXXXXXXX</clientID>
      <xi:include href="/run/keys/github-oauth-XXXXXXXXXXXXXXXXXXX.xml"/>
      <oauthScopes>read:org,user:email</oauthScopes>
    </securityRealm>
  </hudson>


  Corresponding output file (/nix/store/abc...xyz-xinclude.nix):

  ["/run/keys/github-oauth-XXXXXXXXXXXXXXXXXXX.xml"]

*/

# XXX: either string or list of strings
xmlFiles:

let

  inherit (builtins) toString;

  xinclude2nix =
    let
      deps = hpkgs: with hpkgs; [ hxt ];
      ghc = "${haskellPackages.ghcWithPackages deps}/bin/ghc -Wall -static";
    in runCommand "xinclude2nix" {} ''
      ${ghc} -o $out ${./xinclude2nix.hs}
    '';

in runCommand "xinclude.nix" {} ''
  echo ${xinclude2nix} ${toString xmlFiles} >&2
  ${xinclude2nix} ${toString xmlFiles} > $out
  echo -n "$out: " >&2
  cat "$out" >&2
''

