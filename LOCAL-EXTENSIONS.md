# Local extensions and upstream maintenance

DoorBird is a downstream feature. Upstream acceptance is not a prerequisite for
keeping it. The package and host integration are versioned atomically in this
repository; no submodule or separate release coordination is required.

## Ownership and dependency direction

| Area | Owner and contract |
| --- | --- |
| `packages/doorbird_intercom/` | Independent Flutter/Android media plugin, dependencies, native build, sources, licenses, controller and codec tests. Never imports the host. |
| `lib/local/doorbird/` | Host adapter, private profiles and inline camera presentation. Adapts shared UI and host capabilities to the plugin. |
| `lib/local/extensions.dart` | Single composition point: local camera capability, audio ownership, profile provisioning and complete settings reset. |
| `lib/extensions/camera_interaction.dart` | Optional generic camera-view builder and a Listenable flag suspending still-image polling. No DoorBird configuration or media types. |
| `lib/app.dart` | Constructs/disposes local extensions and passes generic display/navigation holds and announcement interruption. Routes imported private settings to the composition point. A sole camera card receives bounded page height so its controls remain visible with system insets. |
| `lib/cards/{env,camera_card}.dart` | Optional camera-view capability with an unlabelled still-image widget. Without it, the existing still-image camera works. |
| `lib/config/settings.dart` | Optional asynchronous provisioning/clear hooks. It does not store or interpret private feature settings. |
| `lib/util/{display,navigation}_controller.dart` | Generic counted, idempotently released holds. These shared capabilities are not owned by DoorBird. |
| `pubspec.yaml`, `pubspec.lock` | One private path dependency; plugin registration and manifest merging are automatic. |

This is the complete review surface in the host for NSP-018. In particular there
are no DoorBird edits in `MainActivity`, the app manifest, app Gradle script or HA
setup screen. Credentials retain the existing private `intercom_profiles` key;
HA settings resaves never rewrite that key. Full local reset must call
`LocalExtensions.clearSettings()`, which invokes the generic host clear hook.

The adapter may depend on the host's sheet buttons, palette, page visibility and interfaces. Its fixed picture/status/action layout owns the transition from still to live; page departure cancels pending profile reads and closes its session. The host must
not depend on media implementation types. `dev/check-local-extensions.py` rejects
feature references leaking into core Dart/Android files and package imports that
point back into the app. Tests separately cover the package and the host adapter.

## Receiving upstream updates

1. Keep `origin/main` as upstream tracking reference and `develop` as the local
   combined branch. Fetch upstream; create an integration branch/worktree from
   current `develop` and merge `origin/main` there. Do not reset local develop or
   rebase its already integrated history onto upstream.
2. Resolve host conflicts against the contract table above. Keep new upstream
   behavior, adapting the small host adapter where interfaces change. Never
   restore an old complete Activity, settings, camera or Gradle file just to keep
   this feature working. A Git merge with no conflicts is not sufficient.
3. Run `python3 dev/check-local-extensions.py`, host Flutter analysis/tests,
   package Flutter tests, app and plugin Android tests. Review resolved Media3
   dependencies whenever upstream changes just_audio, Flutter or Gradle.
4. Merge the verified update into local `develop`. Use the workspace's
   `tools/build-develop.py` for the combined build, then private backups and real
   panel checks. Required extension checks: default camera without profile,
   live preview without microphone, explicit speak/mute, close, background,
   permission denial, screen-off and return/display hold release. Check the
   existing dashboard/MQTT/proximity behavior as well.
5. Fix future extension issues on new feature/fix branches based on current
   develop. Do not repeatedly cherry-pick the original media-spike history: it
   contains integration commits for other local features.

An upstream contribution is prepared separately from a fresh upstream main
checkout, using only the intended generic changes. Never submit `develop` or
this historical feature branch as a wholesale upstream PR. The local plugin,
adapter, private path dependency and device routing setup stay downstream unless
explicitly proposed as a separate contribution.

Future upstream API breaks can still require adapter changes. The isolated
package limits the conflict surface; the contract checks and combined device
validation make those changes reviewable. No claim of automatic compatibility
with unknown future upstream releases is made.

## DoorBird page options

The camera's `intercom` map accepts `profile` (private profile name),
`auto_live: true` (default false), and optionally
`door_opener: {entity: button.example_relay_1}`. Only an explicitly configured
button entity is accepted. Credentials never belong in the dashboard.
The composition root provides a generic HA service callback to local extensions;
DoorBird relay mapping and confirmation remain in `lib/local/doorbird/`.

Auto-live starts once per visible entry, never in the hidden warm-up page.
Ending or a media error does not automatically retry while the page stays open.
The microphone still requires Speak. With an opener configured the four bottom
slots are Live/End, Speak/Mute, Volume and Door buzzer. Volume opens the shared
control sheet. The buzzer opens a confirmation; each confirmation can send at
most one `button.press`, with no retries after timeout or failure. HA acceptance
is labelled as a sent command, never proof of a physically unlocked door.

## Incoming rings

The optional generic MQTT `local/set` hook forwards commands only to the local
composition root. Non-retained `{"type":"doorbird.ring","event_id":"<UTC ISO timestamp>","page":0}`
opens the configured camera page; duplicate, retained, malformed and expired
(10 seconds) events are ignored. No notification backlog is replayed after a
broker/app restart. Configure the dashboard camera return override to 60 seconds
and its home page to the intended destination. HA sends one command and owns no
return timer. Existing MQTT command topics retain their behavior.

The adapter owns a display hold for the incoming preview, released on navigation,
End, background, forced screen saver or disposal. Opening during an incoming ring
must not reset or suspend the navigation deadline; speaking and muted calls retain
both holds. The normal chime completes before auto-live starts and restores the
previous device volume. During an existing media session `IntercomTransport.ring`
mixes the same sound into the 16 kHz output, at gain .6 for preview and .2 for a
conversation, before the AEC render reference. It neither requests audio focus nor
changes the session gain, microphone or native host Activity.

`local_doorbell.pcm` is the existing generated `assets/sounds/doorbell.wav`, linearly
resampled to 16 kHz signed little-endian mono PCM. It contains no recorded audio.
Ring mixer tests cover gain, clipping, finite duration and restarting a notification.

## Companion handoff (NSP-007)

`packages/ha_companion_handoff/` owns Android launch resolution, the temporary
foreground service and its manifest, return handshake and native session journal.
`lib/local/ha_companion/` owns the optional `custom:nspanel-ha-app-card` renderer,
local activation preference and adaptation to display/navigation. Composition
remains in `lib/local/extensions.dart`. The package never imports the host.

Core review surface: optional `PanelEnv.extensionCardBuilder`, registry fallback,
app composition, and the generic `ExternalDisplayLease` in the display controller.
The display session retains the existing detector during a lease; there is no
second sensor algorithm. Real activity foreground state is never falsified.
An external session uses Android idle until screen-off, then transfers dark
wake ownership back before activity resume. Existing near at screen-off must
clear before a new approach can wake. Releasing the lease does not wake.

The card is normal dashboard configuration, including in stacks. No pages or
household entities are injected in the app. A separate downstream JS resource
provides browser preview and editor; it never launches apps in the browser.
The local boolean `companion_handoff_enabled` is provisioned through the existing
setup import, defaults false and survives unrelated settings saves. Full local
reset clears it. Native availability is restricted to tested Android API 27.

For upstream updates run both package analyses/tests and Android tests, the
boundary check, host display/adapter tests and the standalone web card bench.
Test screen-off return with no flash, fresh physical approach, interrupted
sessions, foreground-service cleanup, and DoorBird ring handling while external.
No handoff code belongs in MainActivity or app Android build/manifest files.

## Independent video recovery

RTSP/decoder errors and missing video frames restart only the video player.
HTTP receive/transmit audio, microphone state, AEC, volume and conversation holds
continue unchanged. The controller has a separate `IntercomVideoState`; audio
readiness enables hearing/speaking even while the initial picture is connecting.
The UI hides the stale texture while reconnecting and shows the existing still
preview with an explicit video-connection status.

Retry delays are 1, 2, 5, 10 and then 15 seconds, capped while the audio session
remains healthy. A single rendered frame does not reset the backoff; ten seconds
of stable video do. Initial frame timeout is ten seconds, video-stall timeout five
seconds while playing, with a bounded ten-second grace while Media3 is buffering.
The RTSP read timeout is twelve seconds so it cannot end the stream before this
recovery policy decides. A recovered long frame gap resets the healthy-video
window for backoff. Generation checks discard callbacks from released players. End,
background and screen-off cancel retries. Audio failure still terminates the
session and never automatically reactivates the microphone.

The intercom uses a 250 ms initial / 500 ms rebuffer threshold (1–3 s load-control
buffer), instead of Media3's five-second rebuffer default. The rebuffer wait must
remain well below the five-second frame watchdog: a brief transport interruption
must not trigger a reconnect merely because the player is collecting its buffer.
Bounded ten-second native health logs contain AEC call timings, decoder counters
and numeric player state; retry logs distinguish frame timeout, stream end and
player error. They never include media, credentials or exception messages.

RTP datagrams are preferred for live video so a lost packet does not block the
subsequent pictures behind TCP retransmission. If an attempt delivers no decoded
frame within the existing startup limit, the next attempt forces RTP/TCP. This
choice is session-local and resets on the next explicit session. A gap in an
already working UDP stream does not force a protocol switch. Both paths keep
the same bounded video watchdog and independent HTTP audio.
