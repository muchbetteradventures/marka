#!/bin/bash
set -euo pipefail

SIGNING_IDENTITY="${SIGNING_IDENTITY}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE}"
BINARY_NAME="markie"

# --- Auto-version from conventional commits ---

# Get the latest tag, or default to 0.0.0 if none exists
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
CURRENT_VERSION="${LATEST_TAG#v}"

IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION}"

# Scan commits since last tag for conventional commit prefixes
COMMITS=$(git log "${LATEST_TAG}..HEAD" --pretty=format:"%s" 2>/dev/null || git log --pretty=format:"%s")

BUMP="patch"
while IFS= read -r msg; do
    if echo "$msg" | grep -qiE "^breaking[:(]|^[a-z]+!:"; then
        BUMP="major"
        break
    elif echo "$msg" | grep -qiE "^feat[:(]"; then
        BUMP="minor"
    fi
done <<< "$COMMITS"

case "$BUMP" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac

VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "==> Version bump: ${CURRENT_VERSION} -> ${VERSION} (${BUMP})"

# Update Version.swift
sed -i '' "s/markieVersion = \".*\"/markieVersion = \"${VERSION}\"/" Sources/Markie/Version.swift

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Info.plist

# Commit version bump and tag
git add Sources/Markie/Version.swift Info.plist
git commit -m "release: v${VERSION}"
git tag "v${VERSION}"

echo "==> Tagged v${VERSION}"

# --- Build, sign, notarize ---

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
