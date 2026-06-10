#!/bin/sh

set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

flutter pub get

cd ios
pod install
