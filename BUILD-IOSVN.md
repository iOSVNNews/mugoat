# Muguet IPA build

This fork keeps the upstream app and adds a manual GitHub Actions build on an
Apple Silicon Mac with Xcode 26 or newer and Rust 1.98.1.

Run **Actions → Build Muguet IPA → Run workflow**. Download the **Muguet-IPA**
artifact after the job succeeds. It includes the IPA, SHA-256 checksum, license,
and source/build information.

The initial build uses `bash ./make-ios.sh --ipa` with bundle identifier
`vn.iosvn.muguet`. It is ad-hoc signed and has no Apple provisioning profile;
re-sign it with AltStore or a suitable Apple developer profile to install it.

**No game code or game data is included.** Without your own `game.wasm` compiled
into the executable, the launcher opens but GTA V cannot run. Importing game
data afterwards does not add the missing executable game code. To build a
playable app on a Mac, provide your own copy as described in the upstream
README, then run:

```sh
BUNDLE_ID=vn.iosvn.muguet bash ./make-ios.sh /path/to/game.zip --ipa
```

Upstream source: https://github.com/c22dev/muguet

Initial upstream revision: `366d0ccc00aa67bd88ac9df1fc6fc29fb3fdd577`.

## Build with precompiled game code

The separate **Build encrypted Muguet IPA with game code** workflow downloads a
WASM input with a pinned SHA-256, precompiles it for arm64 iOS, and verifies that
the executable contains the `__GAME` segment. Data and shaders still need to be
imported in the application. No device gameplay result is implied by a successful
build.

The resulting IPA bundle is encrypted with AES-256-GCM before artifact upload.
The artifact key is held in the repository secret `MUGUET_ARTIFACT_KEY` and in an
ignored local key file. Raw inputs, precompiled code, the unencrypted IPA, and
iOS build objects are not uploaded or cached by that workflow. Only the host
compiler and ordinary Rust dependencies are cached.

The owner can decrypt the downloaded artifact locally with:

```sh
node tools/ipa-artifact.cjs decrypt Muguet-game-code.enc Muguet-game-code-bundle.zip /path/to/ipa-output.key
```
