About
=====

Nixsap is a set of modules built on top of
[NixOS](https://nixos.org/)/[Nixpkgs](https://nixos.org/nixpkgs/).  Nixsap
provides NixOS modules in the `nixsap` "namespace", e. g. `nixsap.apps.mariadb`
or `nixsap.system.users`, and adds or overrides some packages in Nixpkgs.
From vanila Nixpkgs, Nixsap relies only on basic services like systemd, ssh, ntpd
and package set (extenting and overriding it).


Features
========

Plug & Play
-----------

Each module under the [modules](./modules) directory is automatically available.
When creating a new machine just use

    imports = [ <nixsap> ];

Each package `foo` under the [modules/pkgs](./modules/pkgs) is automatically available as `pkgs.foo`.
For example:

    modules/pkgs/writeXML.nix        => pkgs.writeXML
    modules/pkgs/rdsdump/default.nix => pkgs.rdsdump

You can use this technics in your own projects.


Automatic unix user id
-----------------------

To create daemon users just add their names into the list
`nixsap.system.users.daemons`.  List `nixsap.system.users.normal`
does the same for users with login shell, and `nixsap.system.groups`
for unix groups.  Users and groups will automatically get their
ids based on their names in a deterministic manner.  See examples
in the [applications directory](./modules/apps) and implementation in
[modules/system/users.nix](modules/system/users.nix). This feature is used
throughout `nixsap.apps`.

Examples:

    # id icinga
    uid=1240920351(icinga) gid=100(users) groups=21(proc),100(users)

    # id pashev
    uid=1141737888(pashev) gid=100(users) groups=100(users),21(proc),62(systemd-journal),1061782283(sysops)

    # id jenkins-dumpoo 
    uid=1201814562(jenkins-dumpoo) gid=1201814562(jenkins-dumpoo) groups=96(keys),1201814562(jenkins-dumpoo)

    # id mariadb
    uid=1213117043(mariadb) gid=1213117043(mariadb) groups=96(keys),1213117043(mariadb)



Keyrings
--------

[Keyrings](modules/deployment/keyrings.nix) provide a means of
deploying secret files with sensitive content.  It's inspired by
[NixOps](https://nixos.org/nixops/) and relies on it as on reference
implementation. Most applications from `nixsap.apps` recognize keys from their
parameters or extract them from configuration files and automatically build
their keyrings.



Ideas
=====


Parametrization
---------------

Everything that _can_ be used at build time should have a parameter (integer,
string, path, etc.).  Examples are TCP port, data directory, UNIX user. TCP
port can be used for configuring firewall or HTTP proxy, data directory can
be used for setting up mount points, UNIX user can be included into extra
groups, etc.  When we have it all parametrized we do not repeat ourselves.

Parametrization also helps modularity. I. e. you can define default set of
values and override only some of them in specific setups.

Some applications accept only discrete set of options, in that case we should
parametrize them all.  Examples are memcached, php-fpm and sproxy2.

Parametrization should give access to all application features. Ideally,
parameters should exactly match to the application options, including
their names and meanings.  Examples are MariaDB and PostgreSQL. This makes
documentation unnecessary, because each parameter is documented somewhere else.

Almost every parameter, if it's not required by application (i. e. has
a built-in default value), should have value `null` by default.  If such
parameter is not set, it is not passed to the application. This is twofold:
more transparency because we use _application's_ defaults (not ours), and it
is safer to use different versions of application, when particular options
may be added or removed.

Even though, if the value of parameter is required at build time, the parameter
should have default value, preferably application's default. Example is
MariaDB's TCP port. We need it to configure firewall, thus we define it to
be 3306 by default.

If application default value is known to be insecure, we should set our own,
_secure_, default value.


Requirements
============

* [nixpkgs](https://nixos.org/nixpkgs/) >= 16.09


License
=======

This project is under the MIT license (see [LICENSE](LICENSE)),
unless stated otherwise in individual files.

