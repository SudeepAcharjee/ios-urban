#!/bin/sh
set -e

git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter

export PATH="$HOME/flutter/bin:$PATH"

flutter --version

cd "$CI_PRIMARY_REPOSITORY_PATH"

flutter pub get

flutter precache --ios

cd ios

pod repo update
pod install --repo-update