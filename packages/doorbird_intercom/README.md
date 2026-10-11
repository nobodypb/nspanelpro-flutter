# Private DoorBird media plugin

This package owns the session controller, Android lifecycle and permissions,
HTTP/RTSP transports, G.711, Media3 dependencies, JNI/AEC build, source archives,
licenses and media-only tests. It has no imports from the NSPanel app. Flutter
registers `DoorBirdPlugin` through `ActivityAware`; the host Activity and Android
app build file contain no extension code. Configuration detach stops media and
resolves pending permission intent as denied; reattachment never resumes a call.

The Dart entry point accepts a private profile and hold/release callbacks. It
knows no Home Assistant entities, dashboard, navigation or host settings. Channel
names remain stable for the deployed client contract. Native Java/JNI names use
the package's own `local.nspanel.doorbird` namespace.

Run `flutter test` here for controller tests. From a Flutter host's Android
project run `./gradlew :doorbird_intercom:testDebugUnitTest`. The package can be
used by a different Flutter host through a path dependency; no MainActivity
edits are required. Supported build environment: Android API 24+, compile SDK
36, AGP 9.1 with built-in Kotlin, Java 17, Python 3.12+, NDK 28.2.13676358 and
CMake 3.22.1. Source archives are SHA-256 checked by `tool/build-apm.py`.

Media3 currently matches the host's just_audio dependency (1.4.1). Gradle may
resolve a newer transitive version after an upstream audio upgrade. Inspect the
resolved release runtime dependencies and revalidate RTSP, focus, pause/resume,
screen-off and JNI on Android 8.1; matching declared versions is not proof.

This remains a feasibility probe, not a released intercom product. Actual speech
quality and the panel's OEM HTTP redirect require separate acceptance. See the
host's `INTERCOM.md` and `LOCAL-EXTENSIONS.md`.
