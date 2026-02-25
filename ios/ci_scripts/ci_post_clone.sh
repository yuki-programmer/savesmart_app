#!/bin/bash
set -euo pipefail
trap 'echo "[ci_post_clone] ERROR on line $LINENO" >&2' ERR

log() {
  echo "[ci_post_clone] $*"
}

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

log "Setting up Flutter"
if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
  FLUTTER_ROOT="$(cd "$(dirname "$FLUTTER_BIN")/.." && pwd)"
  log "Using existing Flutter at $FLUTTER_ROOT"
else
  FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
  FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"

  if [ ! -d "$FLUTTER_ROOT" ]; then
    log "Downloading Flutter SDK ($FLUTTER_CHANNEL)"
    TMP_DIR="$(mktemp -d)"

    python3 - <<'PY' >"$TMP_DIR/flutter_url.txt"
import json
import os
import urllib.request

channel = os.environ.get("FLUTTER_CHANNEL", "stable")
url = "https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json"

data = json.load(urllib.request.urlopen(url))
current = data["current_release"][channel]
for release in data["releases"]:
    if release["hash"] == current:
        print("https://storage.googleapis.com/flutter_infra_release/releases/" + release["archive"])
        break
PY

    FLUTTER_URL="$(cat "$TMP_DIR/flutter_url.txt")"
    if [ -z "$FLUTTER_URL" ]; then
      log "Failed to resolve Flutter SDK URL"
      exit 1
    fi

    log "Flutter URL: $FLUTTER_URL"
    curl -fL "$FLUTTER_URL" -o "$TMP_DIR/flutter.zip"

    FLUTTER_PARENT="$(dirname "$FLUTTER_ROOT")"
    mkdir -p "$FLUTTER_PARENT"
    unzip -q "$TMP_DIR/flutter.zip" -d "$FLUTTER_PARENT"

    rm -rf "$TMP_DIR"
  else
    log "Flutter SDK already exists at $FLUTTER_ROOT"
  fi
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter config --no-analytics
flutter --version
flutter precache --ios

cd "$ROOT_DIR"

log "Running flutter pub get"
flutter pub get

if [ ! -f "ios/Flutter/Generated.xcconfig" ]; then
  log "ERROR: ios/Flutter/Generated.xcconfig was not generated."
  exit 1
fi

log "Ensuring CocoaPods is up to date"
if ! command -v pod >/dev/null 2>&1; then
  log "CocoaPods not found, installing"
  if sudo -n true 2>/dev/null; then
    sudo gem install cocoapods -N
  else
    gem install cocoapods -N --user-install
    export PATH="$(ruby -e 'print Gem.user_dir')/bin:$PATH"
  fi
else
  log "CocoaPods found: $(pod --version)"
  if sudo -n true 2>/dev/null; then
    sudo gem install cocoapods -N
  else
    gem install cocoapods -N --user-install
    export PATH="$(ruby -e 'print Gem.user_dir')/bin:$PATH"
  fi
fi

log "CocoaPods version: $(pod --version)"

log "Installing pods"
cd ios
pod install --repo-update
