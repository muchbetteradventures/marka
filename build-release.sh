#!/bin/bash
set -euo pipefail

# Load signing config from .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    source "${SCRIPT_DIR}/.env"
else
    echo "Error: .env file not found. Copy .env.example to .env and fill in your values."
    exit 1
fi

if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
    echo "Error: SIGNING_IDENTITY not set in .env"
    exit 1
fi
if [[ -z "${KEYCHAIN_PROFILE:-}" ]]; then
    echo "Error: KEYCHAIN_PROFILE not set in .env"
    exit 1
fi

BINARY_NAME="marka"

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
sed -i '' "s/markaVersion = \".*\"/markaVersion = \"${VERSION}\"/" Sources/Marka/Version.swift

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Info.plist

# Commit version bump and tag
git add Sources/Marka/Version.swift Info.plist
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
TAR_NAME="${BINARY_NAME}-${VERSION}.tar.gz"

echo "==> Creating ${DMG_NAME}..."
STAGING_DIR=$(mktemp -d)
cp "${BINARY}" "${STAGING_DIR}/${BINARY_NAME}"
rm -f "${DMG_NAME}"
hdiutil create -volname "Marka ${VERSION}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}"
rm -rf "${STAGING_DIR}"

echo "==> Signing .dmg..."
codesign --sign "${SIGNING_IDENTITY}" "${DMG_NAME}"

echo "==> Creating ${TAR_NAME} for Homebrew..."
tar -czf "${TAR_NAME}" -C .build/release "${BINARY_NAME}"

echo "==> Submitting .dmg for notarization (this may take a minute)..."
xcrun notarytool submit "${DMG_NAME}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait

echo "==> Waiting for ticket propagation..."
sleep 15

echo "==> Stapling notarization ticket to .dmg..."
xcrun stapler staple "${DMG_NAME}"

echo ""
echo "==> Build complete. v${VERSION}"
echo "  Signed binary at: ${BINARY}"
echo "  DMG:              ${DMG_NAME}"
echo "  Homebrew tarball:  ${TAR_NAME}"
echo "  Install locally:  cp ${BINARY} ~/.local/bin/${BINARY_NAME}"

# --- Publish ---

echo ""
echo "==> Pushing to GitHub..."
git push origin main --tags

echo "==> Creating GitHub release..."
gh release create "v${VERSION}" "${DMG_NAME}" "${TAR_NAME}" \
    --title "v${VERSION}" --generate-notes

# --- Update Homebrew tap ---

TAP_REPO="${SCRIPT_DIR}/../homebrew-tap"
FORMULA="${TAP_REPO}/Formula/marka.rb"

if [[ -f "${FORMULA}" ]]; then
    echo "==> Updating Homebrew formula..."
    SHA=$(shasum -a 256 "${TAR_NAME}" | awk '{print $1}')
    sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "${FORMULA}"
    sed -i '' "s/sha256 \".*\"/sha256 \"${SHA}\"/" "${FORMULA}"
    git -C "${TAP_REPO}" add Formula/marka.rb
    git -C "${TAP_REPO}" commit -m "marka ${VERSION}"
    git -C "${TAP_REPO}" push origin main
    echo "==> Homebrew tap updated"
else
    echo "Warning: tap formula not found at ${FORMULA}, skipping"
fi

echo ""
echo "==> Released v${VERSION}"
