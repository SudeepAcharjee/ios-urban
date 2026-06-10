#!/bin/sh

set -e

echo "Installing Flutter..."

git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter

export PATH="$PATH:$HOME/flutter/bin"

flutter --version

cd "$CI_PRIMARY_REPOSITORY_PATH"

flutter pub get

flutter precache --ios

flutter build ios --debug --no-codesign

cd ios

pod install