{ config, lib, pkgs, ... }:

let

  inherit (builtins)
    elem isBool isString ;

  inherit (lib)
    concatMapStringsSep concatStringsSep filter filterAttrs
    mapAttrsToList mkIf mkOption optionalString ;

  inherit (lib.types)
    attrsOf bool either int listOf nullOr path str submodule ;

  cfg = config.nixsap.apps.logrotate;

  concatNonEmpty = sep: list: concatStringsSep sep (filter (s: s != "") list);
  explicit = filterAttrs (n: v: n != "_module" && v != null);
  mandatory = t: mkOption { type = t; };
  optional = t: mkOption { type = nullOr t; default = null; };

  mkConf = name: opts:
    let
      files = concatMapStringsSep " " (f: ''"${f}"'') opts.files;
      show = k: v:
             if elem k ["postrotate" "preremove" "prerotate"]
                then "  ${k}\n    ${v}\n  endscript"
        else if isBool v then optionalString v "  ${k}"
        else if isString v then "  ${k} ${v}"
        else "  ${k} ${toString v}";

    in pkgs.writeText "logrotate-${name}.conf" ''
      ${files} {
      ${concatNonEmpty "\n" (mapAttrsToList show (explicit opts.directives))}
      }
    '';

  configFile = pkgs.writeText "logrotate.conf" ''
    compress
    compresscmd ${pkgs.gzip}/bin/gzip
    compressext .gz
    compressoptions -6
    rotate 4
    uncompresscmd ${pkgs.gzip}/bin/gunzip

    ${concatMapStringsSep "\n" (f: "include ${f}") (mapAttrsToList mkConf (explicit cfg.conf))}
  '';

  entry = {
    options = {
      files = mandatory (listOf path);
      directives = {
        compress        = optional bool;
        compresscmd     = optional path;
        compressext     = optional str;
        compressoptions = optional str;
        copy            = optional bool;
        copytruncate    = optional bool;
        create          = optional (either bool str);
        daily           = optional bool;
        dateext         = optional bool;
        dateformat      = optional str;
        dateyesterday   = optional bool;
        delaycompress   = optional bool;
        extension       = optional str;
        firstaction     = optional path;
        hourly          = optional bool;
        ifempty         = optional bool;
        lastaction      = optional path;
        mail            = optional str;
        mailfirst       = optional bool;
        maillast        = optional bool;
        maxage          = optional int;
        maxsize         = optional int;
        minsize         = optional int;
        missingok       = optional bool;
        monthly         = optional bool;
        nocompress      = optional bool;
        nocopy          = optional bool;
        nocopytruncate  = optional bool;
        nocreate        = optional bool;
        nodateext       = optional bool;
        nodelaycompress = optional bool;
        nomail          = optional bool;
        nomissingok     = optional bool;
        nosharedscripts = optional bool;
        notifempty      = optional bool;
        postrotate      = optional path;
        preremove       = optional path;
        prerotate       = optional path;
        rotate          = optional int;
        sharedscripts   = optional bool;
        size            = optional int;
        su              = optional str;
        uncompresscmd   = optional path;
        weekly          = optional bool;
        yearly          = optional bool;
      };
    };
  };

  exec = pkgs.writeBashScriptBin "logrotate" ''
    exec ${pkgs.logrotate}/bin/logrotate \
      -s '${cfg.stateDir}/status' \
      ${optionalString cfg.verbose " -v"} \
      ${optionalString (cfg.mail != null) " -m '${cfg.mail}'"} \
      ${configFile}
  '';

in {
  options.nixsap.apps.logrotate = {

    stateDir = mkOption {
      description = "Directory for logrotate state file";
      type = path;
      default = "/logrotate";
    };

    conf = mkOption {
      description = "Logrotate configuration";
      type = attrsOf (submodule entry);
      default = {};
    };

    mail = mkOption {
      description = ''
        Tells logrotate which command to use when mailing logs. This command
        should accept two arguments: 1) the subject of the message, and 2)
        the recipient.
      '';
      type = nullOr path;
      default = null;
    };

    verbose = mkOption {
      description = "Turns on verbose mode.";
      type = bool;
      default = true;
    };

    startAt = mkOption {
      description = "Time to start in systemd format";
      type = str;
      default = "hourly";
    };
  };

  config = mkIf ({} != explicit cfg.conf) {
    systemd.services.logrotate = {
      description = "rotates, compresses, and mails system logs";
      inherit (cfg) startAt;
      preStart = ''
        mkdir -p '${cfg.stateDir}'
        chown -Rc root:root '${cfg.stateDir}'
        chmod -Rc u=rwX,g=rX,o= '${cfg.stateDir}'
      '';
      serviceConfig = {
        ExecStart = "${exec}/bin/logrotate";
      };
    };
  };
}

