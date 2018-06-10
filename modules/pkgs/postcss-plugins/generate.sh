#!/bin/sh -e

node2nix -8 --bypass-cache --flatten -i plugins.json -c plugins.nix

