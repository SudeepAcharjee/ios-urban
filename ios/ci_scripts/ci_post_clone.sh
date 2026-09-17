#!/bin/sh
set -e

echo "➡️ Changing directory to workspace root"
cd $CI_PRIMARY_REPOSITORY_PATH

echo "➡️ Installing Flutter"
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

echo "➡️ Precaching iOS artifacts"
flutter precache --ios

echo "➡️ Getting Flutter packages"
flutter pub get

echo "➡️ Installing CocoaPods dependencies"
cd ios
pod deintegrate
pod install --repo-update
echo "✅ Post-clone script completed successfully!"
