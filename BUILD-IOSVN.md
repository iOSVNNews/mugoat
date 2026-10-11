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

## iOSVN rebuild 2

The original `proudly made by c22dev` credit is preserved, with `Rebuild: iOSVN`
added beneath it. The rebuild adds a 120 FPS option on ProMotion devices, a real
render pacer and refresh-rate hint; hardware, temperature and system policy still
determine the achieved frame rate.
The native launch screen also shows both credits while iOS opens the executable.

Touch aiming uses a linear response with an independent aim sensitivity, tap/hold
aim modes, optional aim while firing, a left fire button and drag-to-aim on the
right fire button. Dragging jump, reload and other action buttons no longer rotates
the camera. Gamepad aiming uses the same precision multiplier.

Runtime preparation and game-file validation run off the main UI thread. The
startup overlay shows progress and recoverable errors; caught game-runtime traps
are logged and displayed instead of immediately exiting the application.

The game heap has a 16 GiB ceiling, with a lower maximum chosen from physical RAM
and the actual process memory allowance. Wasmtime uses explicit memory bounds
instead of reserving 16 GiB on every device. Heap growth reports its actual limit,
keeps headroom and avoids speculative over-allocation on iOS. Memory warnings and
low available-memory readings trigger GPU cache recycling and a temporary 30 FPS
limit. Live game textures and buffers are preserved. This reduces avoidable
memory pressure; it cannot make GTA V fit every low-memory device or guarantee
that iOS never terminates the app.

The launcher can share bounded runtime logs, including the previous session.
Logs may contain multiplayer IP addresses. Online status uses server responses,
and reconnects after a timeout. LAN Host/Join uses UDP 47520 with up to 8 players;
Internet play needs a reachable UDP server. Story missions remain single-player.

The build verifies memory/frame/aim policies, a real two-client UDP handshake and
relay, the ARM64 app and embedded AOT game code. These checks do not replace
physical-device gameplay, RAM-pressure and aiming tests.

## Build with precompiled game code

### iOSVN rebuild 3: manifest compatibility

The startup validator in rebuild 2 could reject imported packs when optional
`common/non_final/www/` HTML/CSS/JS documentation differed from its manifest
size. Rebuild 3 reconciles those entries with actual disk sizes, omits absent
web documentation, and supplies the reconciled manifest to the engine in memory.
Previously imported packs do not need to be imported again for this mismatch.
The original manifest on disk is preserved during startup. Import uses the same
validation rules, and updates its staged manifest before replacing the old pack.
Missing or truncated RPF archives and runtime metadata still fail validation.
Regression checks cover the reported `psomismatch.html` mismatch, omitted web
documentation, corrupt runtime assets, unsafe paths and preservation of the
previous pack when an archive is incomplete.

The smaller rebuild 2 IPA uses the same pinned input WASM SHA-256 as the earlier
82,680,451-byte IPA. Its AOT `__GAME` segment is 183,205,888 bytes versus
210,976,768 bytes previously, and all original app assets remain present.

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
