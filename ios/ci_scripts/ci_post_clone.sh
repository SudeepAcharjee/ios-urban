#!/bin/sh

set -e

export LANG=en_US.UTF-8

git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter

export PATH="$HOME/flutter/bin:$PATH"

cd "$CI_PRIMARY_REPOSITORY_PATH"

flutter pub get

flutter precache --ios

cd ios

pod repo update
pod install --repo-update