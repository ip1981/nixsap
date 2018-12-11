#!/bin/sh

node2nix -8 --bypass-cache --flatten -i main.json -c main.nix

