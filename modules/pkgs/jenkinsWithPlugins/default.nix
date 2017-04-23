{ pkgs, lib, stdenv, fetchurl }:

/*

  `pluginsFunc` is a function that should return an attribute set of plugins
  to be included in the WAR.

  The plugins are provided by `pkgs.jenkinsUpdateCenter.plugins`.
  Dependencies between those plugins are automatically resolved within the
  same jenkinsUpdateCenter.

  Example:

    pkgs.jenkinsWithPlugins
      (plugins: {
        inherit (plugins) BlameSubversion ... ;
        inherit (pkgs) my-plugin;
      })

  Each attribute of `plugins` is a derivation and you can return in
  the set any other plugins that are not available in Jenkins registry
  (https://updates.jenkins-ci.org/) or replacing plugins in the registry.

  Non-optional dependencies, if any, are automatically added. Optional
  dependencies are ignored, you have to add them explicitly.

*/

pluginsFunc:

let

  inherit (builtins)
    attrNames fromJSON readFile ;

  inherit (lib)
    concatStrings filter filterAttrs flatten genAttrs mapAttrs
    mapAttrsToList unique ;

  fromBase64 = import ./fromBase64.nix;

  updateCenter =
    let
      registry = fromJSON (readFile pkgs.jenkinsUpdateCenter);
    in
      registry // {
        core = with registry.core; fetchurl {
          inherit url;
          name = "jenkins-core-${version}.war";
          sha1 = fromBase64 sha1;
          meta = registry.core;
        };

        plugins = mapAttrs (
          _: plugin: fetchurl {
            inherit (plugin) url;
            sha1 = fromBase64 plugin.sha1;
            name = "jenkins-plugin-${plugin.name}-${plugin.version}.hpi";
            meta = plugin;
          }
        ) registry.plugins;
      };

  inherit (updateCenter) core;

  neededPlugins =
    let
      rootPlugins = pluginsFunc updateCenter.plugins;
      hasDeps = _: p: (p ? meta) && (p.meta ? dependencies);
      directDeps = nn:
        let
          isRequired = d: ! (d ? optional && d.optional);
          deps = p: map (d: d.name) (filter isRequired p.meta.dependencies);
        in flatten (map (n: deps updateCenter.plugins.${n}) nn);

      getDepsRecursive = nn: if nn == [] then [] else nn ++ getDepsRecursive (directDeps nn);
      depNames = unique (getDepsRecursive (attrNames (filterAttrs hasDeps rootPlugins)));
      deps = genAttrs depNames (n: updateCenter.plugins.${n});
    in deps // rootPlugins;

  pluginsPack = stdenv.mkDerivation {
    name = "jenkins-plugins-pack";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out
      ${concatStrings (
        mapAttrsToList (n: p: ''
          ln -svf '${p}' "$out/${n}.hpi"
        '') neededPlugins)}
    '';
  };

  pack =  stdenv.mkDerivation rec {
    name = "jenkins-${core.meta.version}+plugins.war";

    # https://wiki.jenkins-ci.org/display/JENKINS/Bundling+plugins+with+Jenkins
    build-xml = pkgs.writeXML "jenkins.build.xml"
      ''
      <?xml version="1.0" encoding="UTF-8"?>
      <project basedir="." name="Jenkins-Bundle">
        <target name="bundle" description="Merge plugins into jenkins.war">
          <zip destfile="jenkins.war" level="9">
            <zipfileset src="${core}" />
            <zipfileset dir="${pluginsPack}" prefix="WEB-INF/plugins" />
          </zip>
        </target>
      </project>
      '';

    meta = with stdenv.lib; {
      description = "An extendable open source continuous integration server";
      homepage = http://jenkins-ci.org;
      license = licenses.mit;
      platforms = platforms.all;
    };

    buildInputs = with pkgs; [ ant jdk ];

    phases = [ "buildPhase" "installPhase" ];
    buildPhase = ''
      ln -sf ${build-xml} build.xml
      ant bundle
    '';
    installPhase = "cp jenkins.war $out";
  };

in if neededPlugins == [] then core else pack

