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

echo "➡️ Cleaning old Pods to ensure fresh state"
cd ios
rm -rf Pods
rm -f Podfile.lock
cd ..

echo "➡️ Forcing a full Flutter iOS build to resolve all CocoaPods and Symlinks natively"
flutter build ios --release --no-codesign

echo "✅ Post-clone script completed successfully!"
