#!/bin/bash
set -euo pipefail

echo "[ci_post_clone] Setting up Flutter"
FLUTTER_VERSION=${FLUTTER_VERSION:-stable}
FLUTTER_ROOT="$HOME/flutter"

if [ ! -d "$FLUTTER_ROOT" ]; then
  git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter --version
flutter precache --ios

cd "$(dirname "$0")/../.."

flutter pub get

if [ ! -f "ios/Flutter/Generated.xcconfig" ]; then
  echo "[ci_post_clone] ERROR: ios/Flutter/Generated.xcconfig was not generated."
  exit 1
fi

echo "[ci_post_clone] Installing CocoaPods"
cd ios
pod install --repo-update
