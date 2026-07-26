#!/usr/bin/env bash
set -euo pipefail

PROJECT="DXO24Controller.xcodeproj"
SCHEME="DXO24Controller"
CONFIGURATION=Release
BUILD_DIR=".build"
ARCHIVE_PATH="${BUILD_DIR}/${SCHEME}.xcarchive"
APP_NAME="${SCHEME}.app"
DMG_NAME="${SCHEME}-$(date +%Y%m%d).dmg"

echo "==> Clean"
xcodebuild clean \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -quiet

echo "==> Archive"
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -archivePath "${ARCHIVE_PATH}" \
  -quiet

echo "==> Export .app"
cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}" "${BUILD_DIR}/"

echo "==> Create DMG"
hdiutil create -srcfolder "${BUILD_DIR}/${APP_NAME}" -volname "${SCHEME}" -fs HFS+ "${DMG_NAME}"

echo "==> DMG ready: ${DMG_NAME}"
