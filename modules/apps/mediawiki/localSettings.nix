extensions:

{ lib, ... }:
let

  inherit (builtins) elem;

  inherit (lib)
    concatStringsSep flip genAttrs mergeOneOption mkDefault mkOption
    mkOptionType optionalAttrs optionals types ;
  inherit (types)
    attrsOf bool either enum int listOf nullOr path str submodule ;

  just = t: mkOption { type = t; }; # mergeable defaults
  default = d: t: mkOption { type = t; default = d; }; # overridable defaults
  optional = t: mkOption { type = nullOr t; default = null; };
  set = options: mkOption { type = submodule { inherit options; }; default = {}; };

  # XXX https://github.com/NixOS/nixpkgs/issues/9826
  enum' = values:
    let show = v: let t = builtins.typeOf v;
            in if t == "string" then ''"${v}"''
          else if t == "int" then builtins.toString v
          else ''<${t}>'';
    in mkOptionType {
      name = "one of ${concatStringsSep ", " (map show values)}";
      check = flip elem values;
      merge = mergeOneOption;
    };

  rights = [
    "apihighlimits" "applychangetags" "autoconfirmed" "autopatrol"
    "bigdelete" "block" "blockemail" "bot" "browsearchive"
    "changetags" "createaccount" "createpage" "createtalk"
    "delete" "deletedhistory" "deletedtext" "deletelogentry"
    "deleterevision" "edit" "editinterface" "editmyoptions"
    "editmyprivateinfo" "editmyusercss" "editmyuserjs"
    "editmywatchlist" "editprotected" "editsemiprotected"
    "editusercss" "editusercssjs" "edituserjs" "hideuser" "import"
    "importupload" "ipblock-exempt" "managechangetags" "markbotedits"
    "mergehistory" "minoredit" "move" "move-categorypages"
    "move-rootuserpages" "move-subpages" "movefile" "nominornewtalk"
    "noratelimit" "override-export-depth" "pagelang" "passwordreset"
    "patrol" "patrolmarks" "protect" "proxyunbannable" "purge"
    "read" "reupload" "reupload-own" "reupload-shared" "rollback"
    "sendemail" "siteadmin" "suppressionlog" "suppressredirect"
    "suppressrevision" "unblockself" "undelete" "unwatchedpages"
    "upload" "upload_by_url" "userrights" "userrights-interwiki"
    "viewmyprivateinfo" "viewmywatchlist" "writeapi"
  ]
  ++ optionals extensions.UserPageEditProtection [ "editalluserpages" ]
  ;

  wgGroupPermissions = set ( genAttrs [
    "*" "user" "autoconfirmed" "bot" "sysop" "bureaucrat"
  ] (_:
      set ( genAttrs rights (_: optional bool) )
    )
  );


  wgDefaultUserOptions = set (
    {
      diffonly             = optional bool;
      disablemail          = optional bool;
      enotifminoredits     = optional bool;
      enotifrevealaddr     = optional bool;
      enotifusertalkpages  = optional bool;
      enotifwatchlistpages = optional bool;
      fancysig             = optional bool;
      gender               = optional (enum [ "female" "male" "unknown" ]);
      hideminor            = optional bool;
      justify              = optional bool;
      minordefault         = optional bool;
      nickname             = optional str;
      previewontop         = optional bool;
      quickbar             = optional (enum' [ 0 1 2 3 4 5 ]);
      realname             = optional str;
      rememberpassword     = optional bool;
      underline            = optional (enum' [0 1 2]);
      math                 = optional (enum' [0 1]);
      usenewrc             = optional bool;
      imagesize            = optional int;
      skin                 = optional str;
    } // optionalAttrs extensions.WikiEditor
    {
      usebetatoolbar     = optional bool;
      usebetatoolbar-cgd = optional bool;
      usenavigabletoc    = optional bool;
      wikieditor-preview = optional bool;
      wikieditor-publish = optional bool;
    }
  );

in {
  options = {
    inherit wgDefaultUserOptions;
    inherit wgGroupPermissions;
    wgAllowCopyUploads             = optional bool;
    wgArticlePath                  = optional path;
    wgCheckFileExtensions          = optional bool;
    wgCopyUploadsDomains           = default [] (listOf str);
    wgCopyUploadsFromSpecialUpload = optional bool;
    wgDBcompress                   = optional bool;
    wgDBerrorLog                   = optional path;
    wgDBname                       = default "mediawiki" str;
    wgDBport                       = default "3456" int;
    wgDBserver                     = default "" str;
    wgDBssl                        = optional bool;
    wgDBtype                       = default "postgres" (enum ["mysql" "postgres"]);
    wgDBuser                       = default "mediawiki" str;
    wgDebugLogFile                 = optional path;
    wgEnableUploads                = default false bool;
    wgFileBlacklist                = just (listOf str);
    wgFileExtensions               = just (listOf str);
    wgLanguageCode                 = optional str;
    wgMaxShellMemory               = optional int;
    wgMaxShellTime                 = optional int;
    wgMimeTypeBlacklist            = just (listOf str);
    wgScriptPath                   = optional str;
    wgServer                       = optional str;
    wgShowDBErrorBacktrace         = optional bool;
    wgShowExceptionDetails         = optional bool;
    wgSitename                     = default "Wiki" str;
    wgStrictFileExtensions         = optional bool;
    wgStyleDirectory               = optional path;
    wgStylePath                    = optional path;
    wgUploadDirectory              = default "/mediawiki" path;
    wgUploadPath                   = default "/_files" str;
    wgUrlProtocols                 = just (listOf str);
    wgUsePrivateIPs                = optional bool;
  } // optionalAttrs (extensions.UserPageEditProtection)
  {
    wgOnlyUserEditUserPage = optional bool;
  };

  config = {
    wgUrlProtocols = [
      "//" "bitcoin:" "ftp://" "ftps://" "geo:" "git://" "gopher://"
      "http://" "https://" "irc://" "ircs://" "magnet:" "mailto:"
      "mms://" "news:" "nntp://" "redis://" "sftp://" "sip:"
      "sips:" "sms:" "ssh://" "svn://" "tel:" "telnet://" "urn:"
      "worldwind://" "xmpp:" ];
    wgFileExtensions = [ "gif" "jpeg" "jpg" "png" ];
    wgFileBlacklist = [
      "bat" "cgi" "cmd" "com" "cpl" "dll" "exe" "htm" "html" "jhtml"
      "js" "jsb" "mht" "mhtml" "msi" "php" "php3" "php4" "php5"
      "phps" "phtml" "pif" "pl" "py" "scr" "shtml" "vbs" "vxd"
      "xht" "xhtml" ];
    wgMimeTypeBlacklist = [
      "application/x-msdownload" "application/x-msmetafile"
      "application/x-php" "application/x-shellscript" "text/html"
      "text/javascript" "text/scriptlet" "text/x-bash" "text/x-csh"
      "text/x-javascript" "text/x-perl" "text/x-php" "text/x-python"
      "text/x-sh" ];
  };
}

