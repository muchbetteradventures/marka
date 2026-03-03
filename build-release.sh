#!/bin/bash
set -euo pipefail

SIGNING_IDENTITY="${SIGNING_IDENTITY}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE}"
BINARY_NAME="markie"

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

echo "==> Zipping for notarization..."
rm -f "${BINARY_NAME}.zip"
zip -j "${BINARY_NAME}.zip" "${BINARY}"

echo "==> Submitting for notarization (this may take a minute)..."
xcrun notarytool submit "${BINARY_NAME}.zip" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait

echo "==> Cleaning up zip..."
rm -f "${BINARY_NAME}.zip"

echo "==> Creating .dmg for distribution..."
STAGING_DIR=$(mktemp -d)
cp "${BINARY}" "${STAGING_DIR}/${BINARY_NAME}"
rm -f "${BINARY_NAME}.dmg"
hdiutil create -volname "Markie" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "${BINARY_NAME}.dmg"
rm -rf "${STAGING_DIR}"

echo "==> Stapling notarization ticket to .dmg..."
xcrun stapler staple "${BINARY_NAME}.dmg"

echo ""
echo "Done."
echo "  Signed binary at: ${BINARY}"
echo "  Distributable:    ${BINARY_NAME}.dmg"
echo "  Install locally:  cp ${BINARY} ~/.local/bin/${BINARY_NAME}"
