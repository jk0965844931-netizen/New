#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
BUILD_DIR="$IOS_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Release-iphoneos/LocalAudioPiPTranslator.app"
IPA_DIR="$BUILD_DIR/ipa"
PAYLOAD_DIR="$IPA_DIR/Payload"
IPA_PATH="$BUILD_DIR/LocalAudioPiPTranslator-unsigned.ipa"

rm -rf "$BUILD_DIR"
mkdir -p "$PAYLOAD_DIR"

xcodebuild \
  -project "$IOS_DIR/LocalAudioPiPTranslator.xcodeproj" \
  -scheme LocalAudioPiPTranslator \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH" >&2
  exit 1
fi

cp -R "$APP_PATH" "$PAYLOAD_DIR/"
(cd "$IPA_DIR" && /usr/bin/zip -qry "$IPA_PATH" Payload)

echo "Unsigned IPA created: $IPA_PATH"
