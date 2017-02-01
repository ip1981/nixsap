{ config, pkgs, lib, ... }:

let

  inherit (lib)
    concatMapStrings concatMapStringsSep concatStringsSep
    filterAttrs genAttrs hasPrefix mapAttrs mapAttrsToList mkDefault
    mkEnableOption mkIf mkOption mkOverride optionalAttrs optionalString
    recursiveUpdate;
  inherit (lib.types)
    attrsOf bool either enum int lines listOf nullOr package path
    str submodule unspecified ;
  inherit (builtins)
    attrNames elem isAttrs isBool isList isString ;

  cfg = config.nixsap.apps.mediawiki;
  user = cfg.user;
  php = cfg.php-fpm.package;

  defaultPool = {
    pm.max_children = 10;
    pm.max_requests = 1000;
    pm.max_spare_servers = 5;
    pm.min_spare_servers = 3;
    pm.strategy = "dynamic";
    env.MEDIAWIKI_LOCAL_SETTINGS = "${localSettings}";
    php_value = optionalAttrs (cfg.maxUploadSize != null) {
      post_max_size = 2 * cfg.maxUploadSize;
      upload_max_filesize = cfg.maxUploadSize;
    };
  };

  explicit = filterAttrs (n: v: n != "_module" && v != null);
  concatMapAttrsSep = s: f: attrs: concatStringsSep s (mapAttrsToList f attrs);
  enabledExtentions = attrNames (filterAttrs (_: enabled: enabled) (explicit cfg.extensions));

  keys = mapAttrsToList (_: o: o.password-file) cfg.users;

  settings =
    let
      show = s: n: v:
             if isBool v then (if v then "TRUE" else "FALSE")
        else if isString v then "'${v}'"
        else if isList v then "array(${concatMapStringsSep "," (i: "\n${s}'${toString i}'") v})"
        else if isAttrs v then "array(${concatMapAttrsSep "," (p: q: "\n${s}'${p}' => ${show "${s}  " p q}") (explicit v)})"
        else toString v;
    in pkgs.writePHPFile "LocalSettings.inc.php" ''
      <?php
      ${concatMapAttrsSep "\n"
        (n: v: if isAttrs v
          # XXX This will preserve or replace defaults,
          # but would give odd result if any element were a list:
          then "\$${n} = array_replace_recursive (\$${n}, ${show "  " n v});"
          else "\$${n} = ${show "  " n v};")
        (explicit cfg.localSettings)}
      ?>
    '';

  localSettings = pkgs.writePHPFile "LocalSettings.php" ''
    <?php
      ${concatMapStringsSep "\n  " (e:
        "require_once ('${pkgs.mediawikiExtensions.${e}}/${e}.php');"
        ) enabledExtentions
      }

      ${optionalString (elem "GraphViz" enabledExtentions)
       "$wgGraphVizSettings->execPath = '${pkgs.graphviz}/bin/';"
      }

      ${optionalString (elem "MathJax" enabledExtentions) ''
        # MathJax 0.7:
        MathJax_Parser::$MathJaxJS = '${pkgs.mathJax}/MathJax.js?config=TeX-AMS-MML_HTMLorMML-full';
      ''}

      $wgDiff = '${pkgs.diffutils}/bin/diff';
      $wgDiff3 = '${pkgs.diffutils}/bin/diff3';
      $wgImageMagickConvertCommand = '${pkgs.imagemagick}/bin/convert';
      ${optionalString (cfg.logo != null) ''
        $wgLogo = '${cfg.logo}';
      ''}
      ${optionalString (cfg.maxUploadSize != null)
        "$wgMaxUploadSize = ${toString cfg.maxUploadSize};"
      }

      require_once ('${settings}');

      $wgDirectoryMode = 0750;
    ?>
  '';

  mediawiki-db =
    let
      psql = pkgs.writeBashScript "mw-psql" ''
        set -euo pipefail
        exec ${pkgs.postgresql}/bin/psql -t -w \
          -v ON_ERROR_STOP=1 \
          ${optionalString (cfg.localSettings.wgDBserver != "")
            "-h '${cfg.localSettings.wgDBserver}'"} \
          -p ${toString cfg.localSettings.wgDBport} \
          -U ${toString cfg.localSettings.wgDBuser} \
          -d '${cfg.localSettings.wgDBname}' \
          "$@"
      '';
      mysql = pkgs.writeBashScript "mw-mysql" ''
        set -euo pipefail
        exec ${pkgs.mysql}/bin/mysql -N \
          ${optionalString (cfg.localSettings.wgDBserver != "")
            "-h '${cfg.localSettings.wgDBserver}'"} \
          -u ${toString cfg.localSettings.wgDBuser} \
          -D '${cfg.localSettings.wgDBname}' \
          "$@"
      '';
    in pkgs.writeBashScriptBin "mediawiki-db" ''
      set -euo pipefail
      ${if cfg.localSettings.wgDBtype == "postgres" then ''
        while ! ${psql} -c ';'; do
          sleep 5s
        done
        exist=$(${psql} -c "SELECT COUNT(1) FROM pg_class WHERE relname = 'mwuser';")
        if [ "''${exist//[[:space:]]/}" -eq 0 ]; then
          {
            # XXX this script has BEGIN, but no COMMIT:
            cat ${pkgs.mediawiki}/maintenance/postgres/tables.sql
            echo 'COMMIT;'
          } | ${psql}
        fi
      '' else ''
        while ! ${mysql} -e ';'; do
          sleep 5s
        done
        exist=$(${mysql} -e "SELECT COUNT(1) FROM information_schema.tables
                             WHERE table_schema='${cfg.localSettings.wgDBname}'
                             AND table_name='mwuser'")
        if [ "''${exist//[[:space:]]/}" -eq 0 ]; then
          {
            cat ${pkgs.mediawiki}/maintenance/tables.sql
          } | ${mysql}
        fi
      ''}

      export MEDIAWIKI_LOCAL_SETTINGS='${localSettings}'
      ${php}/bin/php ${pkgs.mediawiki}/maintenance/update.php
      ${concatMapAttrsSep "" (n: o: ''
        pw=$(cat '${o.password-file}')
          if [ -z "$pw" ]; then
            echo 'WARNING: Using random password, because ${o.password-file} is empty or cannot be read' >&2
            pw=$(${pkgs.pwgen}/bin/pwgen -1 13)
          fi
        ${php}/bin/php ${pkgs.mediawiki}/maintenance/createAndPromote.php \
          --force --${o.role} '${n}' "$pw"
      '') cfg.users}
    '';

  mediawiki-upload = pkgs.writeBashScriptBin "mediawiki-upload" ''
    set -euo pipefail
    mkdir -v -p '${cfg.localSettings.wgUploadDirectory}'

    ${optionalString (elem "GraphViz" enabledExtentions)
      # XXX: GraphViz::getUploadSubdir: mkdir(/mediawiki/graphviz/images/, 16872) failed
      # GraphViz fails to create the directory until you create the first graph.
      "mkdir -v -p '${cfg.localSettings.wgUploadDirectory}/graphviz'"
    }

    chmod -Rc u=rwX,g=rX,o= '${cfg.localSettings.wgUploadDirectory}'
    chown -Rc '${cfg.user}:${cfg.user}' '${cfg.localSettings.wgUploadDirectory}'
  '';

  nginx = ''
    ${cfg.nginxServer}

    ${optionalString (cfg.maxUploadSize != null)
      "client_max_body_size ${toString cfg.maxUploadSize};"
    }

    root ${pkgs.mediawiki};
    index index.php;

    ${optionalString (cfg.logo != null) ''
      location = ${cfg.logo} {
        alias ${cfg.logo};
      }
    ''}

    ${optionalString
      (cfg.localSettings.wgEnableUploads
        && hasPrefix "/" cfg.localSettings.wgUploadPath) ''
      location ${cfg.localSettings.wgUploadPath} {
        alias ${cfg.localSettings.wgUploadDirectory};
      }
    ''}

    ${concatMapStrings (e: ''
      location /extensions/${e} {
        alias ${pkgs.mediawikiExtensions.${e}};
      }
      '') enabledExtentions
    }

    ${optionalString (elem "MathJax" enabledExtentions) ''
      location ${pkgs.mathJax} {
        alias ${pkgs.mathJax};
      }
    ''}

    location / {
      try_files $uri $uri/ @rewrite;
    }

    location @rewrite {
      rewrite ^/(.*)$ /index.php?title=$1&$args;
    }

    location ^~ /maintenance/ {
      return 403;
    }

    location ~ \.php$ {
      fastcgi_pass unix:${config.nixsap.apps.php-fpm.mediawiki.pool.listen.socket};
      include ${pkgs.nginx}/conf/fastcgi_params;
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
  '';

in {

  options.nixsap.apps.mediawiki = {
    enable = mkEnableOption "Mediawiki";
    user = mkOption {
      description = ''
        The user the PHP-FPM pool runs as. And the owner of uploaded files.
      '';
      default = "mediawiki";
      type = str;
    };
    nginxServer = mkOption {
      type = lines;
      default = "";
      example = ''
        listen 8080;
        server_name wiki.example.net;
      '';
    };
    php-fpm = {
      package = mkOption {
        description = "PHP package to use";
        type = package;
        default = pkgs.php;
      };
      pool = mkOption {
        description = "Options for the PHP FPM pool";
        type = attrsOf unspecified;
        default = {};
      };
    };
    logo = mkOption {
      description = "The site logo (the image displayed in the upper-left corner of the page)";
      type = nullOr path;
      default = null;
    };
    maxUploadSize = mkOption {
      description = ''
        Maximum allowed size for uploaded files (bytes).
        This affects Mediawiki itself, Nginx and PHP.
      '';
      type = nullOr int;
      default = null;
    };
    localSettings = mkOption {
      description = "Variables in LocalSettings.php";
      type = submodule (import ./localSettings.nix (explicit cfg.extensions));
      default = {};
    };
    extensions = mkOption {
      description = "Mediawiki extensions";
      default = {};
      type = submodule
             { options = mapAttrs
                 (e: _:
                   mkOption {
                      description = "Enable the ${e} extension";
                      type = bool;
                      default = false;
                   }) pkgs.mediawikiExtensions;
             };
    };
    users = mkOption {
      description = "Mediawiki users (only bots or sysops)";
      default = {};
      type = attrsOf (submodule { options = {
        role = mkOption { type = enum [ "bot" "sysop" ]; };
        password-file = mkOption { type = path; };
      }; });
    };
  };

  config = mkIf cfg.enable {
    nixsap.deployment.keyrings.${cfg.user} = keys;
    users.users.${config.nixsap.apps.nginx.user}.extraGroups = [ cfg.user ];

    nixsap.apps.php-fpm.mediawiki = mkOverride 0 {
      inherit (cfg) user;
      inherit (cfg.php-fpm) package;
      pool = recursiveUpdate defaultPool cfg.php-fpm.pool;
    };

    nixsap.apps.nginx.conf.http.servers.mediawiki = nginx;

    systemd.services.mediawiki-db = {
      description = "configure Mediawiki database";
      after = [ "network.target" "local-fs.target" "keys.target" ];
      wants = [ "keys.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        RemainAfterExit = true;
        Type = "oneshot";
        User = cfg.user;
        ExecStart = "${mediawiki-db}/bin/mediawiki-db";
      };
    };

    systemd.services.mediawiki-upload = mkIf cfg.localSettings.wgEnableUploads {
      description = "configure Mediawiki uploads";
      after = [ "local-fs.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        RemainAfterExit = true;
        Type = "oneshot";
        ExecStart = "${mediawiki-upload}/bin/mediawiki-upload";
      };
    };
  };
}

