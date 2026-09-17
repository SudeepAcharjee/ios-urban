#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# Navigate to the root of your cloned repo.
cd $CI_PRIMARY_REPOSITORY_PATH

# 1. Clone the stable Flutter SDK from GitHub.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# 2. Pre-download the underlying artifacts required for iOS compilation.
flutter precache --ios

# 3. Fetch the Flutter project dependencies.
flutter pub get

# 4. Install CocoaPods and the project's iOS dependencies.
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
cd ios
pod install
