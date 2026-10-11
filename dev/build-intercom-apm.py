#!/usr/bin/env python3
"""Build pinned WebRTC APM + JNI for Android. Only writes ignored build outputs."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import venv

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / 'vendor/audio-processing'
HASHES = {
 'webrtc-apm-1.3.tar.gz': '32d008090b8d9a767708224c1e753854f75a947c33b2bb5d889c69ecdfd42250',
 'abseil-cpp-20230125.1.tar.gz': '81311c17599b3712069ded20cca09a62ab0bf2a89dfa16993786c8782b7ed145',
 'abseil-cpp_20230125.1-4_patch.zip': '112ee72052049d930396c2778fc1c6e184137905dd75d60a97dcfc386426610d',
}

def main():
 p = argparse.ArgumentParser()
 p.add_argument('--ndk', required=True)
 p.add_argument('--cmake', required=True)
 p.add_argument('--abis', default='arm64-v8a')
 a = p.parse_args()
 work = ROOT / 'build/intercom-apm'
 work.mkdir(parents=True, exist_ok=True)
 for name, sha in HASHES.items():
  if hashlib.sha256((VENDOR / name).read_bytes()).hexdigest() != sha:
   raise SystemExit('Source checksum mismatch: ' + name)
 source = work / 'webrtc-audio-processing-8e258a1933d405073c9e6465628a69ac7d2a1f13'
 if not source.exists():
  with tarfile.open(VENDOR / 'webrtc-apm-1.3.tar.gz') as archive:
   archive.extractall(work, filter='data')
 cache = source / 'subprojects/packagecache'
 cache.mkdir(exist_ok=True)
 for name in HASHES:
  if name.startswith('abseil'): shutil.copy2(VENDOR / name, cache / name)
 py = work / 'tools/bin/python'
 if not py.exists(): venv.create(work / 'tools', with_pip=True)
 meson = work / 'tools/bin/meson'
 if not meson.exists():
  subprocess.run([str(py), '-m', 'pip', 'install', 'meson==1.5.2'], check=True)
 toolchain = Path(a.ndk) / 'toolchains/llvm/prebuilt/linux-x86_64/bin'
 env = os.environ | {'PATH': str(Path(a.cmake) / 'bin') + os.pathsep + os.environ['PATH']}
 mappings = {'arm64-v8a': ('aarch64', 'aarch64-linux-android24'),
             'armeabi-v7a': ('arm', 'armv7a-linux-androideabi24'),
             'x86_64': ('x86_64', 'x86_64-linux-android24')}
 for abi in a.abis.split(','):
  family, target = mappings[abi]
  cross = work / (abi + '.ini')
  cross.write_text(f"[binaries]\nc = '{toolchain}/{target}-clang'\ncpp = '{toolchain}/{target}-clang++'\nar = '{toolchain}/llvm-ar'\nstrip = '{toolchain}/llvm-strip'\npkg-config = '/usr/bin/false'\n[host_machine]\nsystem = 'android'\ncpu_family = '{family}'\ncpu = '{family}'\nendian = 'little'\n")
  build = work / abi
  if not (build / 'build.ninja').exists():
   subprocess.run([str(meson), 'setup', str(build), str(source), '--cross-file', str(cross), '-Dbuildtype=release', '-Ddefault_library=static', '-Dgnustl=disabled', '--wrap-mode=nodownload'], env=env, check=True)
  subprocess.run([str(meson), 'compile', '-C', str(build), '-j', '2'], env=env, check=True)
  output = ROOT / 'build/intercom-jni' / abi
  output.mkdir(parents=True, exist_ok=True)
  archives = sorted(str(x) for x in build.rglob('*.a'))
  subprocess.run([str(toolchain / (target + '-clang++')), '-shared', '-fPIC', '-O2', '-std=c++17', '-static-libstdc++', '-DWEBRTC_POSIX', '-DWEBRTC_ANDROID', '-I'+str(source/'webrtc'), '-I'+str(source/'subprojects/abseil-cpp-20230125.1'), str(ROOT/'android/app/src/main/cpp/intercom_apm.cpp'), '-Wl,--start-group', *archives, '-Wl,--end-group', '-llog', '-Wl,-z,max-page-size=16384', '-o', str(output/'libintercom_apm.so')], check=True)
  subprocess.run([str(toolchain / (target + '-clang++')), '-fPIE', '-pie', '-O2', '-std=c++17', '-static-libstdc++', '-DWEBRTC_POSIX', '-DWEBRTC_ANDROID', '-I'+str(source/'webrtc'), '-I'+str(source/'subprojects/abseil-cpp-20230125.1'), str(ROOT/'android/app/src/main/cpp/intercom_apm_probe.cpp'), '-Wl,--start-group', *archives, '-Wl,--end-group', '-llog', '-o', str(work/(abi+'-probe'))], check=True)

if __name__ == '__main__': main()
