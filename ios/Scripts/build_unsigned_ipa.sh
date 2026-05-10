#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
BUILD_DIR="$IOS_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products/Release-iphoneos"
APP_PATH="$PRODUCTS_DIR/LocalAudioPiPTranslator.app"
APP_EXTENSION_PATH="$APP_PATH/PlugIns/LocalAudioBroadcastExtension.appex"
IPA_DIR="$BUILD_DIR/ipa"
PAYLOAD_DIR="$IPA_DIR/Payload"
IPA_PATH="$BUILD_DIR/LocalAudioPiPTranslator-unsigned.ipa"
LOG_PATH="$BUILD_DIR/xcodebuild.log"

rm -rf "$BUILD_DIR"
mkdir -p "$PAYLOAD_DIR"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required. Run this script on macOS with Xcode installed." >&2
  exit 127
fi

xcodebuild -version
xcodebuild -list -project "$IOS_DIR/LocalAudioPiPTranslator.xcodeproj"

set +e
xcodebuild \
  -project "$IOS_DIR/LocalAudioPiPTranslator.xcodeproj" \
  -scheme LocalAudioPiPTranslator \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  AD_HOC_CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build 2>&1 | tee "$LOG_PATH"
build_status=${PIPESTATUS[0]}
set -e

if [[ "$build_status" -ne 0 ]]; then
  echo "xcodebuild failed with status $build_status. Full log: $LOG_PATH" >&2
  exit "$build_status"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH" >&2
  find "$PRODUCTS_DIR" -maxdepth 4 -print >&2 || true
  exit 1
fi

if [[ ! -d "$APP_EXTENSION_PATH" ]]; then
  echo "Broadcast extension was not embedded at $APP_EXTENSION_PATH" >&2
  find "$APP_PATH" -maxdepth 4 -print >&2 || true
  exit 1
fi

cp -R "$APP_PATH" "$PAYLOAD_DIR/"
(cd "$IPA_DIR" && /usr/bin/zip -qry "$IPA_PATH" Payload)

echo "Unsigned IPA created: $IPA_PATH"
