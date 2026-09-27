#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WhatsCopy"
EXECUTABLE_NAME="WhatsCopy"
PRODUCT_NAME="WhatsCopy"
DEFAULT_BUNDLE_ID="dev.whatscopy.WhatsCopy"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
BUILD_CONFIGURATION="release"
LOGO_SOURCE="${ROOT_DIR}/Assets/whatscopy-logo.png"
ICONSET_DIR="${DIST_DIR}/${APP_NAME}.iconset"
ICNS_PATH="${RESOURCES_DIR}/AppIcon.icns"

BUNDLE_ID="${BUNDLE_ID:-$DEFAULT_BUNDLE_ID}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APP_SPECIFIC_PASSWORD="${APP_SPECIFIC_PASSWORD:-}"
NOTARIZE="${NOTARIZE:-0}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

require_notarization_environment() {
  if [[ -z "$DEVELOPER_ID_APPLICATION" ]]; then
    echo "error: DEVELOPER_ID_APPLICATION is required when NOTARIZE=1" >&2
    exit 1
  fi

  if [[ -z "$APPLE_ID" || -z "$APPLE_TEAM_ID" || -z "$APP_SPECIFIC_PASSWORD" ]]; then
    echo "error: APPLE_ID, APPLE_TEAM_ID, and APP_SPECIFIC_PASSWORD are required when NOTARIZE=1" >&2
    exit 1
  fi
}

write_info_plist() {
  cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${EXECUTABLE_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 WhatsCopy contributors</string>
</dict>
</plist>
EOF
}

build_release_binary() {
  echo "Building ${PRODUCT_NAME} (${BUILD_CONFIGURATION})..."
  swift build -c "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME"
}

assemble_app_bundle() {
  echo "Assembling ${APP_BUNDLE}..."
  rm -rf "$APP_BUNDLE" "$DMG_PATH"
  mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

  local binary_path
  binary_path="$(swift build -c "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME" --show-bin-path)/${PRODUCT_NAME}"

  cp "$binary_path" "${MACOS_DIR}/${EXECUTABLE_NAME}"
  chmod 755 "${MACOS_DIR}/${EXECUTABLE_NAME}"
  cp -R "$(dirname "$binary_path")/whatscopy_WhatsCopy.bundle" "${RESOURCES_DIR}/"
  install_logo_resources
  write_info_plist
  printf "APPL????" > "${CONTENTS_DIR}/PkgInfo"
}

install_logo_resources() {
  if [[ ! -f "$LOGO_SOURCE" ]]; then
    echo "error: logo asset is missing: ${LOGO_SOURCE}" >&2
    exit 1
  fi

  cp "$LOGO_SOURCE" "${RESOURCES_DIR}/whatscopy-logo.png"
  create_app_icon
}

create_app_icon() {
  echo "Creating app icon from ${LOGO_SOURCE}..."
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  sips -z 16 16 "$LOGO_SOURCE" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
  sips -z 32 32 "$LOGO_SOURCE" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$LOGO_SOURCE" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
  sips -z 64 64 "$LOGO_SOURCE" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$LOGO_SOURCE" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
  sips -z 256 256 "$LOGO_SOURCE" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$LOGO_SOURCE" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
  sips -z 512 512 "$LOGO_SOURCE" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$LOGO_SOURCE" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$LOGO_SOURCE" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
  rm -rf "$ICONSET_DIR"
}

sign_app_if_configured() {
  if [[ -z "$DEVELOPER_ID_APPLICATION" ]]; then
    local identity
    identity="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development:/ {print $2; exit}')"
    if [[ -n "$identity" ]]; then
      echo "Signing ${APP_BUNDLE} with ${identity} because DEVELOPER_ID_APPLICATION is not set."
      codesign --force --sign "$identity" --identifier "$BUNDLE_ID" "$APP_BUNDLE"
    else
      echo "Ad-hoc signing ${APP_BUNDLE} because no Developer ID or Apple Development identity is available."
      codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
    fi
    return
  fi

  echo "Signing ${APP_BUNDLE}..."
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$APP_BUNDLE"

  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

create_dmg() {
  echo "Creating ${DMG_PATH}..."
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_BUNDLE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
}

sign_dmg_if_configured() {
  if [[ -z "$DEVELOPER_ID_APPLICATION" ]]; then
    echo "Skipping DMG signing because DEVELOPER_ID_APPLICATION is not set."
    return
  fi

  echo "Signing ${DMG_PATH}..."
  codesign \
    --force \
    --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$DMG_PATH"

  codesign --verify --verbose=2 "$DMG_PATH"
}

notarize_if_requested() {
  if [[ "$NOTARIZE" != "1" ]]; then
    echo "Skipping notarization because NOTARIZE is not 1."
    return
  fi

  require_notarization_environment

  echo "Submitting ${DMG_PATH} for notarization..."
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --wait

  echo "Stapling notarization ticket..."
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
}

verify_unsigned_artifacts() {
  if [[ ! -x "${MACOS_DIR}/${EXECUTABLE_NAME}" ]]; then
    echo "error: app executable is missing or not executable" >&2
    exit 1
  fi

  if [[ ! -f "$ICNS_PATH" ]]; then
    echo "error: app icon is missing at ${ICNS_PATH}" >&2
    exit 1
  fi

  if [[ ! -f "${RESOURCES_DIR}/whatscopy-logo.png" ]]; then
    echo "error: logo resource is missing from app bundle" >&2
    exit 1
  fi

  plutil -lint "${CONTENTS_DIR}/Info.plist"

  if [[ ! -f "$DMG_PATH" ]]; then
    echo "error: DMG was not created at ${DMG_PATH}" >&2
    exit 1
  fi
}

main() {
  require_command swift
  require_command hdiutil
  require_command iconutil
  require_command plutil
  require_command sips

  if [[ -n "$DEVELOPER_ID_APPLICATION" || "$NOTARIZE" == "1" ]]; then
    require_command codesign
    require_command xcrun
  fi

  build_release_binary
  assemble_app_bundle
  sign_app_if_configured
  create_dmg
  sign_dmg_if_configured
  notarize_if_requested
  verify_unsigned_artifacts

  echo "Release artifact ready: ${DMG_PATH}"
}

main "$@"
