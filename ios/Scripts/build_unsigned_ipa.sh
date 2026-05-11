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
FALLBACK_LOG_PATH="$BUILD_DIR/swiftc-fallback.log"

rm -rf "$BUILD_DIR"
mkdir -p "$PAYLOAD_DIR"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required. Run this script on macOS with Xcode installed." >&2
  exit 127
fi

render_plist() {
  local src="$1"
  local dest="$2"
  local executable="$3"
  local bundle_id="$4"
  local product_name="$5"
  local package_type="APPL"
  if [[ "$(basename "$(dirname "$dest")")" == *.appex ]]; then
    package_type="XPC!"
  fi

  EXECUTABLE_NAME_VALUE="$executable" \
  PRODUCT_BUNDLE_IDENTIFIER_VALUE="$bundle_id" \
  PRODUCT_NAME_VALUE="$product_name" \
  PRODUCT_BUNDLE_PACKAGE_TYPE_VALUE="$package_type" \
  PRODUCT_MODULE_NAME_VALUE="$product_name" \
  perl -0777 -pe '
    s/\$\(EXECUTABLE_NAME\)/$ENV{EXECUTABLE_NAME_VALUE}/g;
    s/\$\(PRODUCT_BUNDLE_IDENTIFIER\)/$ENV{PRODUCT_BUNDLE_IDENTIFIER_VALUE}/g;
    s/\$\(PRODUCT_NAME\)/$ENV{PRODUCT_NAME_VALUE}/g;
    s/\$\(PRODUCT_BUNDLE_PACKAGE_TYPE\)/$ENV{PRODUCT_BUNDLE_PACKAGE_TYPE_VALUE}/g;
    s/\$\(DEVELOPMENT_LANGUAGE\)/en/g;
    s/\$\(PRODUCT_MODULE_NAME\)/$ENV{PRODUCT_MODULE_NAME_VALUE}/g;
  ' "$src" > "$dest"
}

build_with_swiftc_fallback() {
  echo "Attempting direct swiftc unsigned bundle fallback after xcodebuild exit 74…" | tee "$FALLBACK_LOG_PATH"
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun is unavailable; cannot run swiftc fallback." | tee -a "$FALLBACK_LOG_PATH" >&2
    return 74
  fi

  local sdk
  sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
  local target="arm64-apple-ios17.0"

  rm -rf "$PRODUCTS_DIR"
  mkdir -p "$APP_EXTENSION_PATH"

  render_plist "$IOS_DIR/LocalAudioPiPTranslator/Info.plist" "$APP_PATH/Info.plist" "LocalAudioPiPTranslator" "dev.local.audio-pip-translator" "LocalAudioPiPTranslator"
  render_plist "$IOS_DIR/LocalAudioBroadcastExtension/Info.plist" "$APP_EXTENSION_PATH/Info.plist" "LocalAudioBroadcastExtension" "dev.local.audio-pip-translator.broadcast" "LocalAudioBroadcastExtension"

  xcrun swiftc \
    -sdk "$sdk" \
    -target "$target" \
    -O \
    -module-name LocalAudioPiPTranslator \
    "$IOS_DIR/Shared/AppGroupConfig.swift" \
    "$IOS_DIR/LocalAudioPiPTranslator/LocalAudioPiPTranslatorApp.swift" \
    "$IOS_DIR/LocalAudioPiPTranslator/LocalAudioSessionController.swift" \
    "$IOS_DIR/LocalAudioPiPTranslator/ContentView.swift" \
    "$IOS_DIR/LocalAudioPiPTranslator/Broadcast/BroadcastPickerView.swift" \
    "$IOS_DIR/LocalAudioPiPTranslator/PiPSubtitleController.swift" \
    -o "$APP_PATH/LocalAudioPiPTranslator" 2>&1 | tee -a "$FALLBACK_LOG_PATH"

  xcrun swiftc \
    -sdk "$sdk" \
    -target "$target" \
    -O \
    -emit-library \
    -module-name LocalAudioBroadcastExtension \
    "$IOS_DIR/Shared/AppGroupConfig.swift" \
    "$IOS_DIR/LocalAudioBroadcastExtension/SampleHandler.swift" \
    -o "$APP_EXTENSION_PATH/LocalAudioBroadcastExtension" 2>&1 | tee -a "$FALLBACK_LOG_PATH"

  chmod +x "$APP_PATH/LocalAudioPiPTranslator" "$APP_EXTENSION_PATH/LocalAudioBroadcastExtension"
  echo "swiftc fallback created unsigned app and broadcast extension bundles." | tee -a "$FALLBACK_LOG_PATH"
}

xcodebuild -version
if ! xcodebuild -list -project "$IOS_DIR/LocalAudioPiPTranslator.xcodeproj"; then
  echo "warning: xcodebuild -list failed; continuing to the build step so the full build log is captured." >&2
fi

set +e
xcodebuild \
  -project "$IOS_DIR/LocalAudioPiPTranslator.xcodeproj" \
  -scheme LocalAudioPiPTranslator \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
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
  if [[ "$build_status" -eq 74 ]]; then
    build_with_swiftc_fallback
  else
    exit "$build_status"
  fi
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
