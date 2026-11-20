#!/usr/bin/env bash
# Build command for the Render Static Site that hosts the Flutter web app.
# Render has no Flutter installed, so this fetches the same version we use
# locally, then builds into build/web (the site's publish directory).
set -euo pipefail

FLUTTER_VERSION="3.47.7"
FLUTTER_DIR="${HOME}/flutter-${FLUTTER_VERSION}"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter --version
flutter config --no-analytics
flutter pub get
flutter build web --release
