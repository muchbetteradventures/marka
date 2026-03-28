#!/bin/bash
set -euo pipefail

# Build, sign, notarize, and install Marka locally for testing.
# Does NOT bump version, tag, push, or update Homebrew.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    source "${SCRIPT_DIR}/.env"
else
    echo "Error: .env file not found."
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

APP_PATH=".build/DerivedData/Build/Products/Release/Marka.app"
APPEX_PATH="${APP_PATH}/Contents/PlugIns/MarkdownPreview.appex"
INSTALL_PATH="/Applications/Marka.app"
QL_BUNDLE="com.marka.viewer.preview"

# --- Clean up existing installs ---

echo "==> Removing stale QL extension registrations..."
while IFS= read -r line; do
    path=$(echo "$line" | awk '{print $NF}')
    if [[ -n "$path" ]]; then
        echo "  Removing: $path"
        pluginkit -r "$path" 2>/dev/null || true
    fi
done < <(pluginkit -m -p com.apple.quicklook.preview -A -v 2>/dev/null | grep "$QL_BUNDLE" || true)

echo "==> Uninstalling Homebrew version (if present)..."
brew uninstall marka 2>/dev/null || true

echo "==> Removing existing /Applications/Marka.app..."
rm -rf "${INSTALL_PATH}"

# --- Generate Xcode project ---

echo "==> Generating Xcode project..."
xcodegen generate

# --- Build ---

echo "==> Building release..."
xcodebuild -project Marka.xcodeproj \
    -scheme Marka \
    -configuration Release \
    -derivedDataPath .build/DerivedData \
    build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"

if [[ ! -d "${APP_PATH}" ]]; then
    echo "Error: Build product not found at ${APP_PATH}"
    exit 1
fi

# --- Sign ---

echo "==> Signing (inside-out)..."
if [ -d "${APP_PATH}/Contents/Frameworks" ]; then
    find "${APP_PATH}/Contents/Frameworks" -type f \( -name "*.dylib" -o -name "*.framework" \) -print0 | \
        while IFS= read -r -d '' fw; do
            codesign --sign "${SIGNING_IDENTITY}" --options runtime --force "$fw"
        done
fi

codesign --sign "${SIGNING_IDENTITY}" --options runtime --force \
    --entitlements MarkdownPreview.entitlements \
    "${APPEX_PATH}"

codesign --sign "${SIGNING_IDENTITY}" --options runtime --force \
    --entitlements Marka.entitlements \
    "${APP_PATH}"

echo "==> Verifying signature..."
codesign --verify --verbose --deep "${APP_PATH}" 2>&1 | grep -E "valid|error" || true

# --- Notarize ---

echo "==> Creating zip for notarization..."
ZIP_PATH=".build/marka-local-notarize.zip"
rm -f "${ZIP_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "==> Submitting for notarization (this may take a minute)..."
xcrun notarytool submit "${ZIP_PATH}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "${APP_PATH}"

# --- Install ---

echo "==> Installing to /Applications..."
cp -R "${APP_PATH}" "${INSTALL_PATH}"

echo "==> Registering QL extension..."
pluginkit -a "${INSTALL_PATH}/Contents/PlugIns/MarkdownPreview.appex"

echo "==> Registered extensions:"
pluginkit -m -p com.apple.quicklook.preview -A -v 2>/dev/null | grep "$QL_BUNDLE" || echo "  (none found)"

echo "==> Restarting Quick Look daemon..."
killall -9 QuickLookUIService 2>/dev/null || true
qlmanage -r

echo ""
echo "==> Done. Marka installed to /Applications and QL extension registered."
echo "    Check System Settings → Privacy & Security → Extensions → Quick Look"
echo "    to confirm 'Markdown Preview' is enabled."
