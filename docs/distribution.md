# Distribution

## Local Install

```bash
swift build -c release
cp .build/release/marka ~/.local/bin/marka
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

- The **binary** is signed with `--options runtime` (hardened runtime, required for notarization).
- The **DMG** is signed separately. Gatekeeper checks the DMG signature before looking at its contents. Without this, recipients get "open anyway" prompts.
- The notarization **ticket is stapled** to the DMG so Gatekeeper can verify it offline.

### Troubleshooting

- **"no identity found"**: Your Developer ID certificate isn't in your Keychain. Open Keychain Access and check under "My Certificates".
- **Notarization rejected**: Check the log with `xcrun notarytool log <submission-id> --keychain-profile "your-profile"`. Common causes: missing hardened runtime, unsigned dylibs, or unsigned nested executables.
- **"not notarized" on another Mac**: The stapling step may have failed. You can also run `spctl -a -v /path/to/marka` to check.

## Releasing a New Version

The `build-release.sh` script handles versioning, building, signing, and notarizing in one step.

```bash
./build-release.sh
```

This will:
1. Auto-bump the version based on conventional commit prefixes (`feat:` = minor, `fix:` = patch, `breaking:` or `!:` = major)
2. Update `Version.swift` and `Info.plist`
3. Commit the version bump and create a git tag
4. Build a release binary
5. Sign with hardened runtime
6. Create a signed DMG (for direct distribution)
7. Create a tar.gz (for Homebrew)
8. Submit the DMG for notarization and staple the ticket

After the script finishes, it prints the next steps:

```bash
git push origin main --tags
gh release create v0.1.0 marka-0.1.0.dmg marka-0.1.0.tar.gz \
  --title "v0.1.0" --generate-notes
```

Then update the Homebrew formula (see below).

## Homebrew Distribution

### Architecture

Two repos are involved:
- **muchbetteradventures/marka**: the source code. GitHub Releases host the build artifacts.
- **muchbetteradventures/homebrew-tap**: contains `Formula/marka.rb`, which tells Homebrew where to download the binary and how to install it.

We use a **Formula** (not a Cask) because marka is a CLI binary, not a .app bundle. The formula downloads a pre-built, signed tar.gz from GitHub Releases rather than building from source.

### Updating the formula after a release

After uploading artifacts to a GitHub Release:

```bash
# Get the SHA256 of the tarball
shasum -a 256 marka-X.Y.Z.tar.gz
```

Then update `Formula/marka.rb` in the `homebrew-tap` repo:
- Set `version` to the new version
- Set `sha256` to the hash from above
- Commit and push

### Users install with

```bash
brew tap muchbetteradventures/tap
brew install marka
```

Updates:
```bash
brew update
brew upgrade marka
```

### Getting into Homebrew Core

The main `homebrew/core` repo has stricter criteria: the tool needs to be notable, have a stable download URL, and pass review. Start with your own tap, consider Core later if there's demand.

## Project Structure Reference

| File | Purpose |
|---|---|
| `build-release.sh` | Full release pipeline (version, build, sign, notarize) |
| `.env` | Signing identity and keychain profile (gitignored) |
| `.env.example` | Template for `.env` |
| `Info.plist` | macOS app metadata, embedded in binary via linker |
| `Sources/Marka/Version.swift` | Version string, updated by build script |
