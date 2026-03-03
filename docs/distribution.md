# Distribution

## Local Install

```bash
swift build -c release
cp .build/release/markie ~/.local/bin/markie
```

Requires `~/.local/bin` on your `PATH` (add `export PATH="$HOME/.local/bin:$PATH"` to `.zshrc`).

## Signed and Notarized Build

Prerequisites (one-time setup):

1. **Developer ID Application certificate** from the Apple Developer portal. Must be "Developer ID Application", not "Apple Development" or "Apple Distribution".
2. **App Store Connect API key** (.p8 file) from [appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api). Note the Key ID and Issuer ID.
3. **Store notarization credentials** in your Keychain:
   ```bash
   xcrun notarytool store-credentials "literal:${KEYCHAIN_PROFILE}" \
     --key /path/to/AuthKey_XXXXXX.p8 \
     --key-id "YOUR_KEY_ID" \
     --issuer "YOUR_ISSUER_ID"
   ```

Then run:

```bash
./build-release.sh
```

This builds, signs the binary (with hardened runtime), creates a `.dmg`, signs the dmg, submits it for notarization, waits for Apple, and staples the ticket. Output is `markie.dmg`.

### What gets signed and why

- The **binary** is signed with `--options runtime` (hardened runtime, required for notarization).
- The **dmg** is signed separately. Gatekeeper checks the dmg signature before looking at its contents. Without this, recipients get "open anyway" prompts.
- The notarization **ticket is stapled** to the dmg so Gatekeeper can verify it offline.

## Distributing via Homebrew Tap

### Setup (one-time)

1. Make the markie repo public on GitHub (or create a new public one).
2. Create a separate public repo called `homebrew-tap` (e.g. `github.com/yourorg/homebrew-tap`).

### For each release

1. Tag and push:
   ```bash
   git tag v1.0.0
   git push --tags
   ```

2. Run `./build-release.sh` to produce `markie.dmg`.

3. Get the sha256:
   ```bash
   shasum -a 256 markie.dmg
   ```

4. Create a GitHub Release on the markie repo, attach `markie.dmg`.

5. Add or update the cask formula in your `homebrew-tap` repo at `Casks/markie.rb`:
   ```ruby
   cask "markie" do
     version "1.0.0"
     sha256 "the-sha256-from-step-3"

     url "https://github.com/yourorg/markie/releases/download/v#{version}/markie.dmg"
     name "Markie"
     desc "Lightweight terminal-launched Markdown viewer"
     homepage "https://github.com/yourorg/markie"

     binary "markie"

     zap trash: []
   end
   ```

### Users install with

```bash
brew tap yourorg/tap
brew install --cask markie
```

### Getting into Homebrew Core

The main `homebrew-cask` repo has stricter criteria: the app needs to be notable, have a stable download URL, and pass PR review. This is for established tools with a user base, not a realistic day-one target. Start with your own tap.
