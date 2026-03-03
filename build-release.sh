#!/bin/bash
set -euo pipefail

SIGNING_IDENTITY="${SIGNING_IDENTITY}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE}"
BINARY_NAME="markie"

# Read version from the single source of truth
VERSION=$(grep 'markieVersion' Sources/Markie/Version.swift | sed 's/.*"\(.*\)".*/\1/')
echo "==> Version: ${VERSION}"

echo "==> Updating Info.plist version..."
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Info.plist

echo "==> Building release..."
swift build -c release

BINARY=".build/release/${BINARY_NAME}"

echo "==> Signing with hardened runtime..."
codesign --sign "${SIGNING_IDENTITY}" \
         --options runtime \
         --force \
         "${BINARY}"

echo "==> Verifying signature..."
codesign --verify --verbose "${BINARY}"

DMG_NAME="${BINARY_NAME}-${VERSION}.dmg"

echo "==> Creating ${DMG_NAME}..."
STAGING_DIR=$(mktemp -d)
cp "${BINARY}" "${STAGING_DIR}/${BINARY_NAME}"
rm -f "${DMG_NAME}"
hdiutil create -volname "Markie ${VERSION}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}"
rm -rf "${STAGING_DIR}"

echo "==> Signing .dmg..."
codesign --sign "${SIGNING_IDENTITY}" "${DMG_NAME}"

echo "==> Submitting .dmg for notarization (this may take a minute)..."
xcrun notarytool submit "${DMG_NAME}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait

echo "==> Waiting for ticket propagation..."
sleep 15

echo "==> Stapling notarization ticket to .dmg..."
xcrun stapler staple "${DMG_NAME}"

echo ""
echo "Done. v${VERSION}"
echo "  Signed binary at: ${BINARY}"
echo "  Distributable:    ${DMG_NAME}"
echo "  Install locally:  cp ${BINARY} ~/.local/bin/${BINARY_NAME}"
