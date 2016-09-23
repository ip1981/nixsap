{ lib, fetchgit, mediawiki }:

let
  inherit (lib) filter genAttrs;

  bundled = filter (n: n != "out") mediawiki.outputs;

in genAttrs bundled (e: mediawiki.${e}) //
{

  EmbedVideo= fetchgit {
    url = https://github.com/HydraWiki/mediawiki-embedvideo.git;
    rev = "1c1904bfc040bc948726719cbef41708c62546b3";
    sha256 = "07sxpaks1hik710izilpslnqlcjz2nphqkx9b9qh6qv9xb0a9n6v";
  };

  GraphViz = fetchgit {
    url = https://gerrit.wikimedia.org/r/p/mediawiki/extensions/GraphViz.git;
    rev = "c968ec19090ab6febcd12ccd5816c5875fddc9df";
    sha256 = "a0f9b7a67c1b166bba7ce3100b9b2666938af50666a526b1e9e4a83359e4a10d";
  };

/* TODO Use with Mediawiki 1.26+
  MathJax = fetchgit {
    url = https://github.com/hbshim/mediawiki-mathjax.git;
    rev = "56061635eaeffbd13d50d243077e44fcbf3f5da1";
    sha256 = "1xx9cpcl5c8n1jn3qckcva5dnl8z7i1bd2ff4ycpd2cdp930gsy6";
  };
*/

  MathJax = fetchgit {
    url = https://github.com/zalora/Mediawiki-MathJax.git;
    rev = "880adf7f9da55dbe257043fe431f825211ee96e1";
    sha256 = "17s3pbxj6jhywsbdss1hqmss8slb89jkwirlsbd0h16m130q72n8";
  };

  MsUpload = fetchgit {
    url = https://phabricator.wikimedia.org/diffusion/EMSU/extension-msupload.git;
    rev = "d2983b9cd44203173b39e64bf25cdcd73612fcc0";
    sha256 = "18n4iyvp85ipgggjgwrk6pn75gciwrkjb7mr1zvqsh9kv3rpd5n9";
  };

  Sproxy = ./Sproxy; # TODO: review, update & publish

  UserPageEditProtection = fetchgit {
    url = https://gerrit.wikimedia.org/r/p/mediawiki/extensions/UserPageEditProtection.git;
    rev = "13ff835e8278654ab8cfae03c8b8196bdfe6e410";
    sha256 = "0hjsgq8hhqw6wxqfc14jq1wb09q8zf9xv7jz0hkhl5ma6338j7q9";
  };

}

