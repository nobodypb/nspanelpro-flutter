# Panel activity and proximity recovery diagnostics

`PanelTrace` records only allowlisted numeric/boolean fields and fixed reason
strings. Touch contents/coordinates, configuration strings and credentials are
never included. Each record has a process UUID, sequence, wall time, elapsed
realtime and uptime. The host uses `(session, seq)` for deduplication.

## Proximity recovery

Adaptive weak-signal evidence belongs to each display model separately. The
configured delay (120 seconds on the local panel; zero disables recovery) is a
minimum elapsed time, not a promise to recalibrate exactly at that instant.
Display changes preserve evidence; samples from on/off models are never mixed.
Recovery also requires at least 20 observations within the last configured-delay
window (minimum window 10 seconds), three observations within 1.5 seconds, a
stable central 80% range and a fresh sensor feed. Samples are bounded to 64 per
model and at most 10 Hz. A strong confirmed approach, touch or sensor-clock gap
clears pending evidence. Returning to the model's rest band for 500 ms, a changed
direction or expired model-specific observations clears that candidate.

This preserves the existing ambiguity: a very still weak approach may become
the rest value after the chosen delay. A continuously strong approach does not
expire. A prior strong classification is released after two seconds of fresh,
continuously non-strong samples; only then can a new full weak-recovery delay
begin. Touch or sensor gaps clear the old candidate but allow a fresh candidate
while proximity remains active. Fixed and absolute detection do not use adaptive recovery.

`repetition/off_near` is diagnostic only: it counts similar weak entries within
two seconds after OFF, up to 120 seconds apart. It does not suppress a wake or
change the threshold. `wake_request` records accepted/rejected app requests;
`decision=near_blocked` also records the existing forced/external-sleep guard.
The request reason is not proof that the physical display changed. Correlate
with subsequent native `display` records. Platform-only wakes remain unknown;
ring provenance is injected by the local composition root.

`model_age_ms` means age since model creation. `baseline_age_ms` means time since
the last trusted rest update. Recovery diagnostics include the prior ages,
evidence age and sample count; calibration includes old/new baseline and delta.

## Private on-device journal

The same structured records go to a single background writer in app-private
`files/panel-trace/`. The queue is bounded to 512 entries. Segments rotate at
256 KiB or one hour, with at most 64 files / 8 MiB and a three-day age limit
applied on writes. Limits may remove older records sooner. No raw sensor stream
is stored here. A stopped writer does not wake the panel just to prune files.

`TraceProvider` runs in a separate lightweight `:trace` process and exposes only
read-only journal listing/files. It is protected by Android's signature-level
`android.permission.DUMP` (available to ADB shell); arbitrary paths and writes
are rejected. Reading never launches the Flutter activity. ADB collector uses:

```
content query --uri content://nl.mennovanhout.nspanel.develop.paneltrace/files
content read --uri content://nl.mennovanhout.nspanel.develop.paneltrace/files/<name>
```

The host checks the manifest every five seconds and retrieves changed segments.
It commits sequence state only after reading all requested files, writing the
output and syncing it. Partial tails are retried. The independent sensor poll
continues at its existing interval. Host raw values cannot be recovered from a
VM outage; structured activity can be recovered while it remains in this journal.
The updated collector requires this provider; a rollback to an older APK leaves
raw sensor recording available but reports journal read failures.

Overflow/write failures are logged under `NSPanelTraceStatus`; a subsequent
successful journal record includes `buffer_lost_before`. Sequence gaps provide
additional loss evidence. This is bounded best-effort diagnostics: process or
power loss can lose the still queued tail; it never changes display control.
