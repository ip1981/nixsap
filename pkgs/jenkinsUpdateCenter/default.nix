{}:

/*
  This package exists to override Jenkins easily.
  You override this package instead of jenkinsWithPlugins.
  You even can fetch from Jenkins site directly.
*/


/*
  jq to make it human readable:
  curl https://updates.jenkins-ci.org/current/update-center.actual.json | jq . > update-center.actual.json
*/


# capture into nix store to track changes:
"${./update-center.actual.json}"
