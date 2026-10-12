# Private companion handoff

Downstream Flutter/Android plugin. Public Dart controller takes display acquire,
prepare-return and release callbacks. It has no host imports, household mapping,
sensor implementation or HA credentials. Android API 27 is the initial supported
platform; other versions report unavailable rather than guessing background
launch privileges.

A temporary foreground service owns an explicit session and dynamically receives
screen-off. Return requires actual non-interactive/display-off state. The host
prepares navigation/display, acknowledges the session ID, then its captured task
is restored without wake flags. A bounded native recovery fallback restores the
host if Dart is unavailable. The foreground service and CPU handover lock are
released on acknowledged resume. The session journal supports process recovery
but does not relaunch HA or restore a session across reboot. Administrative force
stop is not recoverable by this plugin.

Run `flutter analyze`, `flutter test`, and from host Android Gradle
`:ha_companion_handoff:testDebugUnitTest`. Hardware acceptance must additionally
verify dark task return, physical proximity and the device watchdog.
