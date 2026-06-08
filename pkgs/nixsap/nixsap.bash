#!/usr/bin/env bash

set -eu

SELF=$0

usage() {
  cat <<USAGE
Usage: $SELF [options] <COMMAND> <NIXOS-CONFIG>

COMMAND: build, deploy, send-keys

Options are:
    -I <PATH>         Nix path (can be used multiple times)
    -F <SSH-CONFIG>   SSH client configuration file
    -M <MACHINE-NAME> Target machine (host) name from the SSH configuration file.
                      If omitted, derived from the <NIXOS-CONFIG> file name:
                      <MACHINE-NAME>/default.nix, <MACHINE-NAME>/, <MACHINE-NAME>.nix

    -h                This help message
USAGE
}

die() {
  echo "$SELF: $*" >&2
  exit 1
}

NIX_PATH=( )
SSH_OPTS=( )
SFTP_OPTS=( )

SSH_CONFIG=
MACHINE_NAME=
COMMAND=

while getopts :I:F:M:h opt; do
  case $opt in
    I) NIX_PATH+=( -I "$OPTARG" );;
    F) SSH_CONFIG=$OPTARG;;
    M) MACHINE_NAME=$OPTARG;;
    h) usage; exit 0;;
    *) die "illegal option: -$OPTARG";;
  esac
done
shift $(( OPTIND - 1 ))

if [ $# -eq 0 ]; then
  die "missing <COMMAND>"
fi

case "$1" in
  build|deploy|send-keys) COMMAND="cmd_${1/-/_}";;
  *) die "unkown command: $1";;
esac

shift
if [ $# -eq 0 ]; then
  die "missing <NIXOS-CONFIG>"
fi
NIXOS_CONFIG=$1
NIX_PATH+=( -I "nixos-config=$NIXOS_CONFIG" )

if [ -z "$MACHINE_NAME" ]; then
  case "$NIXOS_CONFIG" in
    */default.nix)
      MACHINE_NAME=$(dirname "$NIXOS_CONFIG")
    ;;
    *.nix)
      MACHINE_NAME=$(basename "$NIXOS_CONFIG" .nix)
    ;;
    *)
      MACHINE_NAME=$(basename "$NIXOS_CONFIG")
    ;;
  esac
fi

if [ -n "$SSH_CONFIG" ]; then
  SSH_OPTS+=( -F "$SSH_CONFIG" )
  SFTP_OPTS+=( -F "$SSH_CONFIG" )
fi

cmd_build() {
  nix-build '<nixpkgs/nixos>' -A config.system.build.toplevel "${NIX_PATH[@]}" --no-out-link
}

cmd_send_keys() {
  sftp_batch=$(nix-build '<nixpkgs/nixos>' -A config.nixsap.deployment.send-keys-sftp "${NIX_PATH[@]}" --no-out-link)
  sftp "${SFTP_OPTS[@]}" -b "$sftp_batch" "$MACHINE_NAME"
}

cmd_deploy() {
  system=$(cmd_build)
  NIX_SSHOPTS="${SSH_OPTS[*]}" nix-copy-closure --to "$MACHINE_NAME" "$system"
  cmd_send_keys

  # shellcheck disable=SC2029
  ssh "${SSH_OPTS[@]}" "$MACHINE_NAME" "$system/bin/switch-to-configuration switch"
}


set -o pipefail
set -x

$COMMAND

