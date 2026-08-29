#!/bin/sh
set -e
[ -n "$CI_BUILD_NUMBER" ] || exit 0
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcrun agvtool new-version -all "$CI_BUILD_NUMBER"
