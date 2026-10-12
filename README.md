# Muguet (iOSVN Rebuild)

A native Mach-O ARM64 port of Grand Theft Auto V for iOS and macOS, powered by WebAssembly ahead-of-time (AOT) compilation and Apple Metal graphics.

---

## Technical Overview

Muguet executes the game's compiled WebAssembly bytecode (`game.wasm`) natively outside of any browser sandbox or JavaScript engine runtime.

- **Execution Engine**: Bytecode is executed via [Wasmtime](https://wasmtime.dev). On iOS, because JIT compilation requires debugging entitlements that are restrictive under normal sideloading, the WebAssembly module is precompiled ahead-of-time (AOT) into an ARM64 Mach-O executable segment (`__GAME`). The game executes at full native machine code speed without requiring JIT entitlements, debuggers, or tethered debugging sessions.
- **Graphics Pipeline**: Game graphics calls route directly through [wgpu](https://wgpu.rs) targeting Apple Metal. This eliminates WebGPU and WebKit compositor overhead, reducing draw-call latency and memory footprint.
- **Frame Pacing**: Integrated `CADisplayLink` synchronization providing stable 60 FPS and 120 FPS output on ProMotion displays (iPhone 13 Pro+ and iPad Pro).
- **Multiplayer Relay**: Low-latency UDP networking layer connecting players to dedicated relay nodes with room isolation.

---

## iOSVN Rebuild Enhancements

This fork adds mobile-first controls, UI customizations, touch map navigation, and quality-of-life improvements:

### 1. Interactive HUD Layout Editor
- **Full-Screen Customizer**: Access the HUD editor directly from the Launcher or mid-game via the in-game menu.
- **Drag & Reposition**: Move any on-screen button, action cluster, or virtual analog stick to any coordinate on screen.
- **Individual Button Scaling**: Scale buttons independently between `0.5×` and `2.2×` using a slider or step controls.
- **Fine Adjustment**: Directional nudging pads for sub-pixel accuracy and per-button or full-HUD reset options.
- **Layout Persistence**: Custom configurations are saved immediately to `UserDefaults` and synchronized into the overlay.

### 2. Mobile Combat & Vehicle Touch Overlay
- High-visibility action glyphs replace generic text labels for combat and driving actions (Aim, Fire, Handbrake, Jump, Vehicle Enter/Exit, Horn, Weapon Wheel, Camera Angle, and Cover).
- Independent aim modes (toggle vs. hold) with dedicated sensitivity curves.
- Multi-touch handling supporting simultaneous aiming, camera panning, movement, and firing.

### 3. Pause Menu & Map Touch Navigation
- **Automatic Overlay Hiding**: Action buttons and sticks automatically conceal when entering the Pause menu (`Esc`), presenting an unobstructed view of the map and menu tabs.
- **Direct Touch Tab Selection**: Tap directly on menu headers (`MAP`, `BRIEF`, `STATS`, `SETTINGS`, `GAME`) to switch tabs.
- **Map Pan & Pinch-to-Zoom**: Pan across Los Santos by dragging across the map area; zoom smoothly using two-finger pinch gestures.
- **Waypoint Placement**: Tap on the map to place GPS destination waypoints.
- **Auxiliary D-Pad Navigation**: Dedicated navigation arrows, tab shifters (`Q` / `E`), zoom steps (`PgUp` / `PgDn`), confirm (`Enter`), and back (`Backspace`) controls.

### 4. Multiplayer Lobby & Room System
- **Room Code Matching**: Create or join isolated lobbies with 6-character room codes (e.g. `SP-1234` for Story/Peaceful, `BX-5678` for Sandbox/PvP).
- **Mode Segregation**: Strict separation between Story Mode instances and Sandbox free-roam sessions.
- **Configurable PvP**: Room hosts can enforce peaceful mode (disabling player-to-player damage and griefing) or enable open combat.
- **Player Identity**: Configurable player nicknames synchronized across the network.
- **Relay Infrastructure**: Dedicated low-latency UDP relay deployed in the Singapore AWS region for optimal Asia-Pacific ping.

### 5. Story Mode Save Persistence
- Persistent sandbox storage for standard GTA V save files (`SGTA50000`).
- Saves are accessible through the iOS Files app (`On My iPhone > Muguet > saves`) and iTunes / Finder file sharing.
- Players can import existing 100% completion save files or back up ongoing campaign progress.

### 6. Centered In-Game Menu
- Centered native modal for quick settings, vehicle spawning, time-of-day/weather adjustments, weapon loadouts, and quick access to the HUD layout editor.

---

## Hardware & System Requirements

| Specification | Minimum | Recommended |
|---|---|---|
| **OS** | iOS 15.0+ / iPadOS 15.0+ | iOS 16.0+ / iPadOS 16.0+ |
| **SoC** | Apple A12 Bionic | Apple A15 Bionic, A16, A17 Pro, or Apple Silicon M1+ |
| **RAM** | 4 GB | 6 GB to 8 GB+ (for high texture streaming stability) |
| **Storage** | ~4 GB free storage | 8 GB+ free storage (for texture caches and shaders) |

> **Note on RAM:** GTA V streams dense world geometry and high-resolution textures. Devices with 4 GB RAM should keep resolution scale at `0.5×` or `0.65×` and texture quality at `Low` to prevent jetsam memory termination by iOS. Devices with 6 GB+ (iPhone 13 Pro and newer, iPad Pro) can safely run at higher resolutions and 60/120 FPS.

---

## Installation & Sideloading

Direct downloads for precompiled IPA binaries are available on the [Releases page](https://github.com/iOSVNNews/muguet/releases/tag/iosvn-runtime8.7-20261012):

- **Build 8.7 IPA:** [Muguet-v8.7.ipa](https://github.com/iOSVNNews/muguet/releases/download/iosvn-runtime8.7-20261012/Muguet-v8.7.ipa)
- **Build Revision:** 8.7 (Extended Virtual Addressing & Increased Memory Limit entitlements, native Mach-O ARM64 `__GAME` segment)
- **SHA-256:** `b5d70b6144145d8a2b676ce6a0f5e48bc868056dfc1aa31c0b9b4b2bbcbecd4f`

Mirror release repository: [iOSVNNews/muguet-ios-build Releases](https://github.com/iOSVNNews/muguet-ios-build/releases).

### Sideloading Methods:
- **TrollStore (Recommended)**: Grants unrestricted memory limits without expiration or developer certificate revokes.
- **AltStore / SideStore**: Requires 7-day resigning. Standard profile signing supported.
- **Feather / Scarlet / Sideloadly / Esign**: Sign using your personal, developer, or enterprise certificate. The IPA package includes standard `Payload/Muguet.app` root hierarchy for zero-configuration signing.
- **Xcode**: Build and deploy directly using your personal or paid Apple Developer team ID.

---

## Game Assets

Muguet is an open-source engine reimplementation and does **not** contain copyrighted game assets, audio, or textures.

To run the game, you need a compatible asset package (`game.zip`) containing:
```text
data/
  manifest.json
  ...
b/<build_number>/
  shaders/
    index.json
    ...
```

On first launch, Muguet presents the native iOS document picker. Select your `game.zip` file; the app extracts and caches the assets in its sandboxed Documents folder.

---

## Building from Source

### Prerequisites (macOS):
- Apple Silicon Mac running macOS 14 (Sonoma) or newer
- Xcode 26 or newer (with iOS SDK and Command Line Tools)
- Rust toolchain 1.98.1 with the iOS target:
  ```bash
  rustup toolchain install 1.98.1
  rustup target add aarch64-apple-ios --toolchain 1.98.1
  ```
- [XcodeGen](https://github.com/yonaskolb/XcodeGen):
  ```bash
  brew install xcodegen
  ```

### Build Commands:

**Build iOS IPA:**
```bash
# Build an IPA bundle containing precompiled game code
./make-ios.sh <path/to/game.zip> --ipa
```

**Build macOS Application:**
```bash
./make-app.sh
# Output will be located at build/Muguet.app
```

---

## Multiplayer Protocol

Muguet communicates over UDP (default port `47520`). Multiplayer relays sync player transform matrices, vehicle states, ped animations, and combat events.

- To run a private relay server:
  ```bash
  cargo run --bin muguet-server -- --port 47520
  ```
- In the iOS Launcher, configure your custom server address under **Settings > Multiplayer > Server IP**.

---

## Credits & Upstream

- **Original Architecture & macOS/iOS Port**: Constantin Clerc ([@c22dev](https://github.com/c22dev))
- **Community Contributions**:
  - [Kagander](https://github.com/Kagander): Minimap projection & blip rendering fixes
  - [inj-src](https://github.com/inj-src): Multi-threaded BC block texture decompression
  - [Dbhardwaj99](https://github.com/Dbhardwaj99): Filesystem storage and disk space reporting
  - [dre4moff](https://github.com/dre4moff): Background state and controller input release
- **iOSVN Rebuild**: Touch controls architecture, HUD customizer, pause menu touch navigation, UDP room routing, and build automation.

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
