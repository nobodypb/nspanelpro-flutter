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
