{ config, pkgs, lib, ...}:

let

  inherit (lib)
    concatMapStrings filterAttrs mapAttrs mapAttrsToList mkOption unique ;
  inherit (lib.types)
    attrsOf path str submodule ;

  explicit = filterAttrs (n: v: n != "_module" && v != null);
  apps = explicit config.nixsap.apps.cli;

  exec = name: { user, command, ... }:
    let
      cc = "${pkgs.gcc}/bin/gcc -Wall -Wextra -Werror -s -std=gnu99 -O2";
      uid = toString config.users.users.${user}.uid;
      gid = uid;
      src = pkgs.writeText "${name}.c" ''
        #include <unistd.h>
        #include <grp.h>
        #include <pwd.h>
        #include <stdio.h>
        #include <stdlib.h>
        #include <sys/types.h>

        int main (int __attribute__((unused)) argc, char *argv[])
        {
          int rc;

          if (getuid() != ${uid}) {
            if (geteuid() != 0) {
              fprintf(stderr, "Forbidden.\n");
              return EXIT_FAILURE;
            }

            rc = initgroups("${user}", ${gid});
            if (0 != rc) {
              perror("initgroups()");
              return EXIT_FAILURE;
            }

            rc = setgid(${gid});
            if (0 != rc) {
              perror("setgid()");
              return EXIT_FAILURE;
            }

            rc = setuid(${uid});
            if (0 != rc) {
              perror("setuid()");
              return EXIT_FAILURE;
            }

            if ((getuid() != ${uid}) || (geteuid() != ${uid})) {
              fprintf(stderr, "Something went wrong.\n");
              return EXIT_FAILURE;
            }

            struct passwd * pw = getpwuid(${uid});
            if (NULL == pw) {
              perror("getpwuid()");
              return EXIT_FAILURE;
            }

            if (NULL != pw->pw_dir) {
              rc = chdir(pw->pw_dir);
              if (0 != rc) {
                rc = chdir("/");
              }
            } else {
              rc = chdir("/");
            }
            if (0 != rc) {
              perror("chdir()");
              return EXIT_FAILURE;
            }
          }

          argv[0] = "${command}";
          execv(argv[0], argv);

          perror("execv()");
          return EXIT_FAILURE;
        }
      '';
    in pkgs.runCommand name {} "${cc} -o $out ${src}";

  cliapp = submodule({name, ...}:
  {
    options = {
      user = mkOption {
        description = ''
          User (and group) to run as. Only users in this group can execute
          this application.
          '';
        type = str;
        default = name;
      };
      command = mkOption {
        description = "Path to executable";
        type = path;
      };
    };
  });

in {
  options.nixsap = {
    apps.cli = mkOption {
      description = ''
        Command line applications that should run as other users and likely
        have special privileges, e. g. to access secret keys.  This is
        implemented with setuid-wrappers. Each wrapper is launched as root,
        immediately switches to specified user, then executes something
        useful. This is like sudo, but access is controlled via wrapper's
        group: only users in wrapper's group can execute the wrapper.

        Starting as set-uid-non-root is not sufficient, because we might
        need supplementary groups, like "keys".
      '';
      type = attrsOf cliapp;
      default = {};
    };
  };

  config = {
    nixsap.system.users.daemons = unique (mapAttrsToList (_: a: a.user) apps);
    security.wrappers = mapAttrs (n: a:
      { source = exec n a;
        owner = "root";
        group = a.user;
        setuid = true;
        setgid = false;
        permissions = "u+rx,g+x,o=";
      }) apps;
  };
}

