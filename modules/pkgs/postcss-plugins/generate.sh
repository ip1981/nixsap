#!/bin/sh -e

node2nix --flatten -i plugins.json -c plugins.nix

