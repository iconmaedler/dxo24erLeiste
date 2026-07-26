#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

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
if [ -d "${BUILD_DIR}/${APP_NAME}" ]; then
  rm -rf "${BUILD_DIR:?}/${APP_NAME}"
fi
cp -R "${APP_PATH}" "${BUILD_DIR}/"

echo "==> Create DMG (verbose)"
hdiutil create -ov -verbose \
  -srcfolder "${BUILD_DIR}/${APP_NAME}" \
  -volname "${SCHEME}" \
  -fs HFS+ \
  "${DMG_NAME}"

if [ ! -f "${DMG_NAME}" ]; then
  echo "ERROR: hdiutil did not create ${DMG_NAME}" >&2
  exit 1
fi

echo "==> DMG contents"
ls -lh "${DMG_NAME}"
echo "==> DMG ready: ${DMG_NAME}"
