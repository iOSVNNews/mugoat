#!/bin/bash
# Build an unsigned IPA from YOUR OWN game files.
# Usage: ./build_ipa.sh https://my-pc.tailnet-name.ts.net [--paid]   (files from your server)
#        ./build_ipa.sh --mirror /path/to/game-folder [--paid]     (files already on this machine:
#                                                                    the folder with data/manifest.json and b/)
#   --lite  the Lite build for iPhones with little memory (about 4 GB of RAM); see PGLiteMode
#   Both IPAs are always made: Mugoat-AppleID-Free.ipa and Mugoat-Cert-Paid.ipa (extra memory).
# Needs: an Apple Silicon Mac (or the GitHub Actions workflow), Xcode, xcodegen.
set -euo pipefail
SERVER=""
MIRROR=""
if [ "${1:-}" = "--mirror" ]; then MIRROR="$(cd "${2:?Usage: ./build_ipa.sh --mirror /path/to/game-folder [--paid]}" && pwd)"; shift 2
else SERVER="${1:?Usage: ./build_ipa.sh https://your-server [--paid]  or  ./build_ipa.sh --mirror /path [--paid]}"; shift; fi
ENTITLEMENTS=App/Free.entitlements
LITE=false
for option in "$@"; do
  case "$option" in
    --paid) ENTITLEMENTS=App/Full.entitlements ;;
    --lite) LITE=true ;;
  esac
done
cd "$(dirname "$0")/app"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
# The system Python runs natively on Apple Silicon (a Rosetta Python would
# make the engine tools build for the wrong CPU).
PY="${PYTHON:-/usr/bin/python3}"

if [ -n "$SERVER" ]; then
  "$PY" Scripts/fetch_game_files.py --server "$SERVER" --out Build/Inputs/mirror
  MIRROR="$PWD/Build/Inputs/mirror"
fi
"$PY" Scripts/check_game_files.py --mirror "$MIRROR"
mkdir -p Build/Online
IPHONEOS_DEPLOYMENT_TARGET=16.0 cargo build --manifest-path ../online-bridge/Cargo.toml --release --lib --target aarch64-apple-ios
cp ../online-bridge/target/aarch64-apple-ios/release/libmugoat_online.a Build/Online/
test -s Build/Online/libmugoat_online.a
mkdir -p Resources
cp "$MIRROR/data/manifest.json" Resources/manifest.json
test -s Resources/manifest.json
if [ "${PG_REUSE_PREPARED:-0}" = "1" ] && [ -s Generated/native-prepared-v1.txt ] && [ -s Generated/game_0.c ] && [ -s Generated/MugoatCommands.c ] && [ -s GeneratedResources/shaders-iphoneos.metallib ]; then
  xcodegen generate --spec project.yml
else
  "$PY" Scripts/prepare.py --mirror "$MIRROR"
fi
# The app opens with your server already filled in (without one, it asks where your files are).
/usr/libexec/PlistBuddy -c "Set :PGDefaultAssetServer $SERVER" App/Info.plist
/usr/libexec/PlistBuddy -c "Set :PGLiteMode $LITE" App/Info.plist

# Fail on host Objective-C syntax errors before compiling the large generated engine (from R007).
xcrun --sdk iphoneos clang -fsyntax-only -fobjc-arc -target arm64-apple-ios16.0 -std=gnu11 -DWASM_RT_USE_MMAP=0 -DWASM_RT_MEMCHECK_BOUNDS_CHECK=1 \
  -isysroot "$(xcrun --sdk iphoneos --show-sdk-path)" -I Source -I Generated \
  -I Tools/wabt-1.0.42/include -I Tools/wabt-1.0.42/share/wabt/wasm2c \
  Source/NativeAssets.m Source/VisualEffects.m

xcodebuild -project PlayGTA5Native.xcodeproj -scheme PlayGTA5Native \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath Build/Release -jobs "$JOBS" \
  GCC_OPTIMIZATION_LEVEL=2 SWIFT_OPTIMIZATION_LEVEL=-O DEBUG_INFORMATION_FORMAT=dwarf \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS" build > Build/xcodebuild.log 2>&1 || {
  grep -E 'error:' Build/xcodebuild.log | head -20
  echo "Build failed; the full log is app/Build/xcodebuild.log"; exit 1; }
grep -E 'BUILD SUCCEEDED' Build/xcodebuild.log

APP=Build/Release/Build/Products/Release-iphoneos/PlayGTA5Native.app
ROOT_DIR="$(cd .. && pwd)"
printf '%s\n' "${GITHUB_SHA:-local}" > "$APP/iosvn-build-revision.txt"
cp Resources/manifest.json "$APP/manifest.json"
test -s "$APP/manifest.json"

# 1. Build IPA for Free Apple ID (SideStore / AltStore standard)
STAGE_FREE=Build/IPA-Free
rm -rf "$STAGE_FREE"
mkdir -p "$STAGE_FREE/Payload"
ditto "$APP" "$STAGE_FREE/Payload/PlayGTA5Native.app"
codesign --force --sign - --entitlements App/Free.entitlements --generate-entitlement-der "$STAGE_FREE/Payload/PlayGTA5Native.app"
(cd "$STAGE_FREE" && zip -qry "$ROOT_DIR/Mugoat-AppleID-Free.ipa" Payload)
echo "Done (Free Apple ID): $ROOT_DIR/Mugoat-AppleID-Free.ipa"

# 2. Build IPA for Paid Certificate / Developer Account (extra memory entitlements)
STAGE_PAID=Build/IPA-Paid
rm -rf "$STAGE_PAID"
mkdir -p "$STAGE_PAID/Payload"
ditto "$APP" "$STAGE_PAID/Payload/PlayGTA5Native.app"
codesign --force --sign - --entitlements App/Full.entitlements --generate-entitlement-der "$STAGE_PAID/Payload/PlayGTA5Native.app"
(cd "$STAGE_PAID" && zip -qry "$ROOT_DIR/Mugoat-Cert-Paid.ipa" Payload)
cp "$ROOT_DIR/Mugoat-Cert-Paid.ipa" "$ROOT_DIR/Mugoat.ipa"
echo "Done (Paid Certificate): $ROOT_DIR/Mugoat-Cert-Paid.ipa"

