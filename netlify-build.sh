#!/usr/bin/env bash
set -euo pipefail

# Instala Flutter (canal stable) dentro del entorno de build de Netlify
FLUTTER_DIR=".flutter-sdk"
FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "==> Clonando Flutter $FLUTTER_VERSION..."
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$FLUTTER_DIR"
fi

export PATH="$PWD/$FLUTTER_DIR/bin:$PATH"

flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
flutter pub get
flutter build web --release
