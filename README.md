Requirements
============

* [nixpkgs](https://nixos.org/nixpkgs/) >= 16.09


License
=======

This project is under the MIT license (see [LICENSE](LICENSE)),
unless stated otherwise in individual files.


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

