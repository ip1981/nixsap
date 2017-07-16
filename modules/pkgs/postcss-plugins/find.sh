#!/bin/sh -e

curl --globoff 'https://registry.npmjs.org/-/_view/byKeyword?startkey=["postcss-plugin"]&endkey=["postcss-plugin",{}]&group_level=2' \
  | jq '.rows | map(.key | .[1])' > plugins.json

