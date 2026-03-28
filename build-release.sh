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
APP_NAME="Marka"

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

# Increment build number
BUILD_NUMBER_FILE="${SCRIPT_DIR}/build-number.txt"
if [[ -f "${BUILD_NUMBER_FILE}" ]]; then
    BUILD_NUMBER=$(($(cat "${BUILD_NUMBER_FILE}") + 1))
else
    BUILD_NUMBER=1
fi
echo "${BUILD_NUMBER}" > "${BUILD_NUMBER_FILE}"
echo "==> Build number: ${BUILD_NUMBER}"

# Update Version.swift (version + build number)
sed -i '' "s/let markaVersion = \".*\"/let markaVersion = \"${VERSION}\"/" Sources/Marka/Version.swift
sed -i '' "s/let markaBuildNumber = [0-9]*/let markaBuildNumber = ${BUILD_NUMBER}/" Sources/Marka/Version.swift

# Update Info.plists
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" Marka-Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Marka-Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" MarkdownPreview-Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" MarkdownPreview-Info.plist

# Commit version bump and tag
git add Sources/Marka/Version.swift Marka-Info.plist MarkdownPreview-Info.plist build-number.txt
git commit -m "release: v${VERSION}"
git tag "v${VERSION}"

echo "==> Tagged v${VERSION}"

# --- Generate Xcode project ---

echo "==> Generating Xcode project..."
xcodegen generate

# --- Build ---

echo "==> Building release..."
xcodebuild -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath .build/DerivedData \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS="" \
    build

APP_PATH=".build/DerivedData/Build/Products/Release/${APP_NAME}.app"
BINARY="${APP_PATH}/Contents/MacOS/${APP_NAME}"

if [[ ! -d "${APP_PATH}" ]]; then
    echo "Error: Build product not found at ${APP_PATH}"
    exit 1
fi

# --- Sign ---

echo "==> Signing with hardened runtime (inside-out)..."
# Sign all frameworks first, then extension, then app.
# --deep would overwrite the extension's entitlements.
if [ -d "${APP_PATH}/Contents/Frameworks" ]; then
    echo "  Signing frameworks..."
    find "${APP_PATH}/Contents/Frameworks" -type f \( -name "*.dylib" -o -name "*.framework" \) -print0 | while IFS= read -r -d '' fw; do
        codesign --sign "${SIGNING_IDENTITY}" --options runtime --force "$fw"
    done
fi

codesign --sign "${SIGNING_IDENTITY}" \
         --options runtime \
         --force \
         --entitlements MarkdownPreview.entitlements \
         "${APP_PATH}/Contents/PlugIns/MarkdownPreview.appex"

codesign --sign "${SIGNING_IDENTITY}" \
         --options runtime \
         --force \
         --entitlements Marka.entitlements \
         "${APP_PATH}"

echo "==> Verifying signature..."
codesign --verify --verbose --deep "${APP_PATH}"

DMG_NAME="${BINARY_NAME}-${VERSION}.dmg"
TAR_NAME="${BINARY_NAME}-${VERSION}.tar.gz"

echo "==> Creating ${DMG_NAME}..."
STAGING_DIR=$(mktemp -d)
cp -R "${APP_PATH}" "${STAGING_DIR}/"

# Create a symlink to /Applications for drag-install
ln -s /Applications "${STAGING_DIR}/Applications"

rm -f "${DMG_NAME}"
hdiutil create -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}"
rm -rf "${STAGING_DIR}"

echo "==> Signing .dmg..."
codesign --sign "${SIGNING_IDENTITY}" "${DMG_NAME}"

echo "==> Creating ${TAR_NAME} for Homebrew..."
tar -czf "${TAR_NAME}" -C ".build/DerivedData/Build/Products/Release" "${APP_NAME}.app"

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
echo "  App bundle:       ${APP_PATH}"
echo "  DMG:              ${DMG_NAME}"
echo "  Homebrew tarball:  ${TAR_NAME}"

# --- Publish ---

echo ""
echo "==> Merging to main and pushing..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
    git checkout main
    git merge "${CURRENT_BRANCH}" --no-edit
fi
git push origin main --tags

echo "==> Creating GitHub release..."
gh release create "v${VERSION}" "${DMG_NAME}" "${TAR_NAME}" \
    --title "v${VERSION}" --generate-notes

# --- Update Homebrew tap ---

TAP_REPO="${HOME}/Experimental/homebrew-tap"
CASK="${TAP_REPO}/Casks/marka.rb"

if [[ -f "${CASK}" ]]; then
    echo "==> Updating Homebrew cask..."
    SHA=$(shasum -a 256 "${DMG_NAME}" | awk '{print $1}')
    sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "${CASK}"
    sed -i '' "s/sha256 \".*\"/sha256 \"${SHA}\"/" "${CASK}"
    git -C "${TAP_REPO}" add Casks/marka.rb
    git -C "${TAP_REPO}" commit -m "marka ${VERSION}"
    git -C "${TAP_REPO}" push origin main
    echo "==> Homebrew tap updated"
else
    echo "Warning: cask not found at ${CASK}, skipping"
fi

echo ""
echo "==> Released v${VERSION}"
