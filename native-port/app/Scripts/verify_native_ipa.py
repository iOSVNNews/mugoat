"""Verify the shipped executable, not just Xcode project settings."""
import argparse
import hashlib
import json
import plistlib
import struct
import zipfile
from pathlib import Path

def version(value): return f'{value >> 16}.{(value >> 8) & 255}.{value & 255}'

def verify(path, revision=None):
    with zipfile.ZipFile(path) as package:
        prefix = 'Payload/PlayGTA5Native.app/'
        info = plistlib.loads(package.read(prefix+'Info.plist'))
        executable = package.read(prefix+info['CFBundleExecutable'])
        header = struct.unpack_from('<IiiIIIII', executable)
        if header[0] != 0xfeedfacf or header[1] != 0x0100000c: raise ValueError('Expected native ARM64 Mach-O')
        offset, minimum, platform = 32, None, None
        for _ in range(header[4]):
            kind, size = struct.unpack_from('<II',executable,offset)
            if size<8: raise ValueError('Invalid Mach-O load command')
            if kind==0x32:
                platform, minimum = struct.unpack_from('<II',executable,offset+8)
            elif kind==0x25 and minimum is None:
                minimum = struct.unpack_from('<I',executable,offset+8)[0]; platform=2
            offset += size
        if (minimum or 0) < 0x0e0000 or (minimum or 0) > 0x100000 or platform != 2: raise ValueError(f'Wrong binary deployment: {version(minimum or 0)}, platform {platform}')
        if info.get('MinimumOSVersion') not in ('14.0', '15.0', '16.0'): raise ValueError(f"Wrong bundle minimum OS: {info.get('MinimumOSVersion')}")
        if info['CFBundleIdentifier']!='vn.iosvn.mugoat': raise ValueError('Save-preserving bundle ID changed')
        if info['CFBundleShortVersionString']!='1.1.4' or info['CFBundleVersion']!='14': raise ValueError('Old build/version')
        if any(name.startswith(prefix) and name.endswith(('.wasm','.cwasm')) for name in package.namelist()): raise ValueError('Unexpected VM game payload')
        for forbidden in [b'wasmtime_runtime',b'wgpu_core',b'wasmtime::']:
            if forbidden in executable: raise ValueError('Old VM/graphics runtime remains in executable')
        if not any(name.startswith(prefix) and name.endswith('.metallib') for name in package.namelist()): raise ValueError('Missing precompiled Metal shaders')
        actual_revision = package.read(prefix+'iosvn-build-revision.txt').decode().strip()
        if revision and actual_revision!=revision: raise ValueError('IPA source revision mismatch')
        icon_files=[name for name in package.namelist() if name.startswith(prefix+'AppIcon') and name.endswith('.png')]
        if not icon_files: raise ValueError('Missing Springboard app icon')
        return {'ipa':str(path),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'architecture':'ARM64 native','binary_minimum_os':version(minimum),'bundle_minimum_os':info['MinimumOSVersion'],
                'bundle_id':info['CFBundleIdentifier'],'version':'1.1.4 (14)','revision':actual_revision,'metal_library':True,
                'vm_game_payload':False,'old_vm_graphics_runtime':False,'app_icon_files':icon_files}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('ipa',type=Path);parser.add_argument('--revision');args=parser.parse_args()
    print(json.dumps(verify(args.ipa,args.revision),indent=2))
