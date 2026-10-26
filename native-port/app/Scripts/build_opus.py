#!/usr/bin/env python3
"""Build libopus (BSD-3-Clause, Xiph.Org) for the app: the game's Opus audio is decoded natively.

The game ships libopus 1.5 compiled to WebAssembly; translated by wasm2c it costs a large share of the
audio thread. Source/NativeOpus.c hands each frame to this native build instead (same version, float
build, NEON on arm64). The release archive is checked against Xiph's published SHA-256.

    python3 Scripts/build_opus.py --sdk iphoneos [--sdk iphonesimulator]
writes Tools/opus-lib/<sdk>/libopus.a (the project links Tools/opus-lib/$(PLATFORM_NAME)).
"""
import argparse
import hashlib
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.request
from pathlib import Path

VERSION = '1.5.2'
URL = f'https://downloads.xiph.org/releases/opus/opus-{VERSION}.tar.gz'
SHA256 = '65c1d2f78b9f2fb20082c38cbe47c951ad5839345876e46941612ee87f9a7ce1'
root = Path(__file__).resolve().parents[1]
source = root / f'Tools/opus-{VERSION}'

parser = argparse.ArgumentParser()
parser.add_argument('--sdk', action='append', choices=['iphoneos', 'iphonesimulator'])
sdks = parser.parse_args().sdk or ['iphoneos']

def download_with_retry(url, destination, expected_sha256, max_retries=5):
    headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Apple Silicon) AppleWebKit/537.36'}
    req = urllib.request.Request(url, headers=headers)
    for attempt in range(1, max_retries + 1):
        try:
            print(f'Downloading opus from {url} (attempt {attempt}/{max_retries})...')
            with urllib.request.urlopen(req, timeout=60) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() == expected_sha256:
                destination.write_bytes(data)
                return
            print(f'Attempt {attempt}: checksum mismatch, retrying...')
        except Exception as e:
            print(f'Attempt {attempt} failed: {e}')
            if attempt < max_retries:
                time.sleep(2 * attempt)
    sys.exit('Failed to download libopus after multiple attempts.')

if not (source / 'CMakeLists.txt').exists():
    archive = root / f'Tools/opus-{VERSION}.tar.gz'
    archive.parent.mkdir(parents=True, exist_ok=True)
    if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        download_with_retry(URL, archive, SHA256)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        sys.exit('libopus archive checksum mismatch.')
    sys.path.insert(0, str(Path(__file__).parent))
    from safe_extract import extract
    with tarfile.open(archive) as package:
        extract(package, root / 'Tools')

for sdk in sdks:
    library = root / f'Tools/opus-lib/{sdk}/libopus.a'
    # CMAKE_SYSTEM_PROCESSOR: a cross build for iOS doesn't set it, and without it libopus leaves out its
    # NEON code (every 64-bit iPhone has NEON, so it is presumed rather than detected).
    args = ['-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_SYSTEM_NAME=iOS', '-DCMAKE_SYSTEM_PROCESSOR=aarch64',
            f'-DCMAKE_OSX_SYSROOT={sdk}', '-DCMAKE_OSX_ARCHITECTURES=arm64', '-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0',
            '-DOPUS_BUILD_TESTING=OFF', '-DOPUS_BUILD_PROGRAMS=OFF', '-DBUILD_SHARED_LIBS=OFF',
            '-DOPUS_INSTALL_PKG_CONFIG_MODULE=OFF', '-DOPUS_INSTALL_CMAKE_CONFIG_MODULE=OFF']
    stamp = library.with_suffix('.args')
    if library.exists() and stamp.exists() and stamp.read_text() == ' '.join(args):
        print(f'libopus {VERSION} for {sdk} already built.')
        continue
    build = root / f'Tools/opus-build/{sdk}'
    shutil.rmtree(build, ignore_errors=True)
    subprocess.run(['cmake', '-S', str(source), '-B', str(build), *args], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['cmake', '--build', str(build), '--config', 'Release', '-j', '4'], check=True, stdout=subprocess.DEVNULL)
    library.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(build / 'libopus.a', library)
    stamp.write_text(' '.join(args))
    print(f'libopus {VERSION} for {sdk}: {library.relative_to(root)}')
