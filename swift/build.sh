#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Instala XcodeGen: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate

CONFIG="${1:-Debug}"
DERIVED="$(pwd)/build"

xcodebuild \
  -project PDFAudiobookStudio.xcodeproj \
  -scheme PDFAudiobookStudio \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=YES \
  build

APP="$DERIVED/Build/Products/$CONFIG/PDF Audiobook Studio.app"
echo "App compilada: $APP"
open "$APP"
