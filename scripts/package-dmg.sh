#!/usr/bin/env bash
set -euo pipefail

PROJECT="DXO24Controller.xcodeproj"
SCHEME="DXO24Controller"
CONFIGURATION=Release
BUILD_DIR=".build"
ARCHIVE_PATH="${BUILD_DIR}/${SCHEME}.xcarchive"
APP_NAME="${SCHEME}.app"
DMG_NAME="${SCHEME}-$(date +%Y%m%d).dmg"

# determine project vs workspace
WORKSPACE="${PROJECT%.*}.xcworkspace"
BUILD_FLAGS=()
if [ -d "${WORKSPACE}" ]; then
  echo "Detected workspace: ${WORKSPACE}"
  BUILD_FLAGS+=( "-workspace" "${WORKSPACE}" )
else
  BUILD_FLAGS+=( "-project" "${PROJECT}" )
fi

echo "==> Clean"
xcodebuild "${BUILD_FLAGS[@]}" -scheme "${SCHEME}" -configuration "${CONFIGURATION}" clean

echo "==> Archive (verbose)"
xcodebuild "${BUILD_FLAGS[@]}" -scheme "${SCHEME}" -configuration "${CONFIGURATION}" -archivePath "${ARCHIVE_PATH}" archive

echo "==> Verify archive contents"
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}"
if [ ! -d "${APP_PATH}" ]; then
  echo "ERROR: expected app at ${APP_PATH} not found. Listing archive:"
  ls -R "${ARCHIVE_PATH}" || true
  exit 1
fi

echo "==> Export .app"
rm -rf "${BUILD_DIR:?}/${APP_NAME}" || true
cp -R "${APP_PATH}" "${BUILD_DIR}/"

echo "==> Create DMG"
hdiutil create -srcfolder "${BUILD_DIR}/${APP_NAME}" -volname "${SCHEME}" -fs HFS+ "${DMG_NAME}"

echo "==> DMG ready: ${DMG_NAME}"
