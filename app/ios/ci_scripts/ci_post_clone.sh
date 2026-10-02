#!/bin/sh

# Prepare the Flutter subproject after Xcode Cloud clones the repository.
set -eu

: "${CI_PRIMARY_REPOSITORY_PATH:?Xcode Cloud repository path is unavailable}"

FLUTTER_VERSION="3.44.4"
FLUTTER_ROOT="$HOME/flutter-$FLUTTER_VERSION"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi

export FLUTTER_ROOT
export PATH="$FLUTTER_ROOT/bin:$PATH"

cd "$CI_PRIMARY_REPOSITORY_PATH/app"

flutter precache --ios
flutter pub get

if ! command -v pod >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
fi

cd ios
pod install
