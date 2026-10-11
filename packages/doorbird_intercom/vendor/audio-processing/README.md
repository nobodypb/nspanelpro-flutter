# Intercom audio processing sources

WebRTC APM 1.3, packaged by PulseAudio; upstream commit
`8e258a1933d405073c9e6465628a69ac7d2a1f13` from
https://gitlab.freedesktop.org/pulseaudio/webrtc-audio-processing.
The source archive includes the original WebRTC sources and license notices.
Abseil 20230125.1 and its Meson WrapDB patch are the dependencies pinned by that
release. Archives are source distributions, not prebuilt native binaries.
All three SHA-256 hashes are checked by `tool/build-apm.py`.
The build uses Meson 1.5.2, Android NDK 28.2.13676358 and CMake's Ninja.
Python 3.12+ with venv/pip is required. First build installs pinned Meson;
source compilation afterwards is offline. Outputs are under ignored `build/`.
No AEC dumps, recordings, network transport, or cloud service are included in APM.
