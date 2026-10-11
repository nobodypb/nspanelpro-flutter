# DoorBird media feasibility increment (NSP-018)

This is an opt-in media probe, not the completed intercom feature. Door and IR
commands and automatic ringing are not enabled. Existing cameras are unchanged
until an `intercom.profile` reference is explicitly added to a camera card.
Opening that card plays live video and outside audio. Only an explicit Speak
command requests microphone permission and starts capture. Close/background/
screen-off/focus loss stop all media. Reopening never resumes the microphone.

Private `setup.json` provisioning adds `intercom_profiles`, a map indexed by
profile name. Each profile contains `host` (hostname or IPv4), `username`,
`password`, and `certificate_sha256` (64 lowercase hex digits). Obtain that pin
from the known local device through a trusted provisioning path. No trust-all
fallback exists in the app; certificate changes require reprovisioning.
Never put credentials or this private map into Lovelace, screenshots, logs or Git.

A camera references the profile through `intercom: {profile: entrance}`.
Without a valid private profile it displays a configuration error. A profile is
not inferred from a Home Assistant camera entity. Keep the DoorBird account's
watch-always permission available for manually initiated calls.

The probe uses pinned Media3 1.4.1 (matching the existing audio dependency) for
video-only RTSP/TCP, and DoorBird HTTP audio with short-lived sessions obtained
over certificate-pinned HTTPS. Audio stays in the LAN. AEC3 and noise reduction
run locally through WebRTC APM, built from verified source archives; see
`packages/doorbird_intercom/vendor/audio-processing/README.md`. Media3 logging is disabled because RTSP
errors can contain credential-bearing URIs. Only typed errors and counters
cross the Flutter channel. Media is never recorded.

Speech uses 16 kHz mono AudioRecord, AEC3 with the rendered reference, WebRTC
resampling to 8 kHz, and G.711 mu-law. Mute stops AudioRecord and sends only
synthetic silence on an established upload. The frontend reports microphone
activity, not a guarantee that someone at the door heard it. Device speech
quality and real app-preemption behavior must be physically accepted before
promoting this probe into a completed feature.

The pure native `arm64-v8a-probe` executable in `build/intercom-apm` tests AEC
with deterministic synthetic echo. It does not access microphone or speaker.
Build and deploy only the combined develop state using the workspace workflow.

Panel deployment prerequisite: the tested OEM image redirects all outbound TCP
port 80 traffic to its local web UI on 8082. HTTP audio cannot work through that
rule. The feasibility test temporarily exempted only the develop application's
UID and the configured DoorBird IPv4 destination/port 80 from that redirect.
It did not disable the panel web server or modify other applications' routing.
Persistent provisioning and reboot acceptance remain open until the physical
media gate passes. The app itself never edits firewall rules. Unexpected audio
content types are rejected before any bytes reach the speaker.

The implementation is isolated as a local plugin and host adapter. See
[LOCAL-EXTENSIONS.md](LOCAL-EXTENSIONS.md) for contracts and the upstream update
workflow. Private profiles are owned by the adapter; host HA settings only expose
a generic provisioning hook. Use `LocalExtensions.clearSettings()` for a full
local reset including private profiles.
