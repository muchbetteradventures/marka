# Distribution

## Local Install

```bash
xcodegen generate
xcodebuild -project Marka.xcodeproj -scheme Marka -configuration Release build
```

The built app is at `DerivedData/Build/Products/Release/Marka.app`. To use the CLI:

```bash
ln -sf /path/to/Marka.app/Contents/MacOS/Marka ~/.local/bin/marka
```

Requires `~/.local/bin` on your `PATH` (add `export PATH="$HOME/.local/bin:$PATH"` to `.zshrc`).

## Signing and Notarization

### Prerequisites (one-time setup)

1. **Developer ID Application certificate** from the Apple Developer portal. Must be "Developer ID Application", not "Apple Development" or "Apple Distribution".

2. **App Store Connect API key** (.p8 file) from [appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api). Note the Key ID and Issuer ID.

3. **Store notarization credentials** in your Keychain:
   ```bash
   xcrun notarytool store-credentials "your-profile-name" \
     --key /path/to/AuthKey_XXXXXX.p8 \
     --key-id "YOUR_KEY_ID" \
     --issuer "YOUR_ISSUER_ID"
   ```
   The profile name you choose here is what goes in `.env` as `KEYCHAIN_PROFILE`.

4. **Create your `.env` file** from the template:
   ```bash
   cp .env.example .env
   ```
   Fill in your `SIGNING_IDENTITY` and `KEYCHAIN_PROFILE`. This file is gitignored.

### What gets signed and why

- The **.app bundle** is signed with `--deep --options runtime` (hardened runtime, required for notarization). This covers the main binary and the embedded QuickLook extension.
- The **DMG** is signed separately. Gatekeeper checks the DMG signature before looking at its contents. Without this, recipients get "open anyway" prompts.
- The notarization **ticket is stapled** to the DMG so Gatekeeper can verify it offline.

### Troubleshooting

- **"no identity found"**: Your Developer ID certificate isn't in your Keychain. Open Keychain Access and check under "My Certificates".
- **Notarization rejected**: Check the log with `xcrun notarytool log <submission-id> --keychain-profile "your-profile"`. Common causes: missing hardened runtime, unsigned dylibs, or unsigned nested executables.
- **"not notarized" on another Mac**: The stapling step may have failed. You can also run `spctl -a -v /path/to/Marka.app` to check.

## Releasing a New Version

The `build-release.sh` script handles the full pipeline: versioning, building, signing, notarizing, GitHub release, and Homebrew tap update.

```bash
./build-release.sh
```

This will:
1. Auto-bump the version based on conventional commit prefixes (`feat:` = minor, `fix:` = patch, `breaking:` or `!:` = major)
2. Update `Version.swift`, `Marka-Info.plist`, and `MarkdownPreview-Info.plist`
3. Commit the version bump and create a git tag
4. Generate the Xcode project via XcodeGen
5. Build the .app bundle with xcodebuild
6. Sign the .app with hardened runtime
7. Create a signed DMG (with /Applications symlink for drag-install)
8. Create a tar.gz (for Homebrew)
9. Submit the DMG for notarization and staple the ticket
10. Push to GitHub and create a release
11. Update the Homebrew tap formula (if the tap repo exists)

## Homebrew Distribution

### Architecture

Two repos are involved:
- **muchbetteradventures/marka**: the source code. GitHub Releases host the build artifacts.
- **muchbetteradventures/homebrew-tap**: contains the Homebrew formula/cask for installation.

Now that marka is a .app bundle, the tap will need to switch from a Formula to a **Cask**. The cask installs the .app to `/Applications` and symlinks the CLI binary to `/usr/local/bin/marka`.

### Users install with

```bash
brew tap muchbetteradventures/tap
brew install --cask marka
```

Updates:
```bash
brew update
brew upgrade --cask marka
```

## Project Structure Reference

| File | Purpose |
|---|---|
| `project.yml` | XcodeGen project definition (run `xcodegen generate` to create .xcodeproj) |
| `build-release.sh` | Full release pipeline (version, build, sign, notarize, publish) |
| `.env` | Signing identity and keychain profile (gitignored) |
| `.env.example` | Template for `.env` |
| `Marka-Info.plist` | Main app Info.plist (UTI declarations, app metadata) |
| `MarkdownPreview-Info.plist` | QuickLook extension Info.plist (supported content types) |
| `Marka.entitlements` | App entitlements |
| `MarkdownPreview.entitlements` | Extension entitlements |
| `Sources/Marka/Version.swift` | Version string, updated by build script |
| `Sources/Marka/` | Main app sources |
| `Sources/Shared/` | Rendering code shared between app and QL extension |
| `Sources/MarkdownPreview/` | QuickLook extension sources |
