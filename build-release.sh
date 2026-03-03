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

echo "==> Stapling notarization ticket..."
xcrun stapler staple "${BINARY}"

echo "==> Cleaning up zip..."
rm -f "${BINARY_NAME}.zip"

echo ""
echo "Done. Signed and notarized binary at: ${BINARY}"
echo "Install with: cp ${BINARY} ~/.local/bin/${BINARY_NAME}"
