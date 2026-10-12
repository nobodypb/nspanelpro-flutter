import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/util/proximity_detector.dart';

class Replay {
  Replay({int seconds = 120}) {
    d = ProximityDetector(
      adaptive: true,
      noiseMultiplier: 3,
      recalibrateSeconds: seconds,
      onTrace: (event, fields) => events.add({'event': event, ...fields}),
    );
    // Two independent models: screen on=20, screen off=12.
    feed(20, 30);
    dark(true);
    feed(12, 30);
  }
  late ProximityDetector d;
  final events = <Map<String, Object?>>[];
  int now = 0;
  void feed(double value, int count) {
    for (var i = 0; i < count; i++) {
      now += 100;
      d.feed(value, now);
    }
  }

  void dark(bool value) => d.dark(value, now: now);
  void cycle({bool strong = false, bool touch = false}) {
    dark(true);
    feed(16, 8);
    dark(false);
    feed(strong ? 50 : 20, 162);
    if (touch) d.touch(now);
  }
}

void main() {
  test('old stable samples still require fresh confirmation on return', () {
    final r = Replay();
    r.feed(16, 300);
    r.dark(false);
    r.feed(20, 1000);
    r.dark(true);
    r.feed(16, 1);
    expect(r.d.recalibrations, 0);
    r.feed(16, 3);
    expect(r.d.recalibrations, 1);
  });

  test('unstable weak values cannot recalibrate even after the delay', () {
    final d = ProximityDetector(
      adaptive: true,
      noiseMultiplier: 8,
      recalibrateSeconds: 120,
    );
    for (var i = 0; i < 30; i++) {
      d.feed(20, i * 100);
    }
    for (var i = 30; i < 2000; i++) {
      d.feed(i.isEven ? 29 : 35, i * 100);
    }
    expect(d.recalibrations, 0);
    expect(d.baseline, 20);
  });

  test('120 second evidence spans display changes without mixing models', () {
    final r = Replay();
    for (var i = 0; i < 7; i++) {
      r.cycle();
    }
    expect(r.d.recalibrations, 0);
    final before = r.now;
    r.cycle();
    expect(r.d.recalibrations, 0); // First return is still before 120 s.
    r.dark(true);
    r.feed(16, 8);
    expect(r.d.recalibrations, 1);
    expect(r.d.baseline, 16);
    expect(r.now - before, greaterThanOrEqualTo(17000));
    r.dark(false);
    expect(r.d.baseline, 20);
    final ready = r.events.singleWhere((e) => e['reason'] == 'ready');
    expect(ready['evidence_ms'], greaterThanOrEqualTo(120000));
    expect(ready['sample_count'], greaterThanOrEqualTo(20));
    expect(
      r.events.any((e) => e['reason'] == 'off_near' && (e['count'] as int) > 1),
      true,
    );
    final count = r.d.entries;
    r.cycle();
    expect(r.d.entries, count); // Corrected baseline re-arms normally.
  });

  test(
    'continuous strong proximity never becomes a baseline after a switch',
    () {
      final r = Replay();
      r.feed(50, 10);
      r.dark(false);
      r.feed(50, 1500);
      expect(r.d.near, true);
      expect(r.d.recalibrations, 0);
      expect(r.d.baseline, 20);
    },
  );

  test('touch and strong observations discard cross-state evidence', () {
    for (final touch in [true, false]) {
      final r = Replay();
      for (var i = 0; i < 12; i++) {
        r.cycle(touch: touch, strong: !touch);
      }
      expect(r.d.recalibrations, 0);
      expect(
        r.events.any((e) => e['reason'] == (touch ? 'touch' : 'strong')),
        true,
      );
    }
  });

  test('a sensor outage cannot mature old evidence', () {
    final r = Replay();
    for (var i = 0; i < 6; i++) {
      r.cycle();
    }
    r.now += 180000;
    r.cycle();
    r.dark(true);
    r.feed(16, 30);
    expect(r.d.recalibrations, 0);
    expect(r.events.any((e) => e['reason'] == 'sensor_gap'), true);
  });

  test('old evidence expires while the other model keeps getting samples', () {
    final r = Replay();
    r.feed(16, 8);
    r.dark(false);
    r.feed(20, 1400);
    r.dark(true);
    r.feed(16, 30);
    expect(r.d.recalibrations, 0);
    expect(r.events.any((e) => e['reason'] == 'expired'), true);
  });

  test('restored values cancel suspicion; setting zero disables recovery', () {
    final r = Replay();
    r.feed(16, 8);
    r.feed(12, 20);
    expect(r.events.any((e) => e['reason'] == 'restored'), true);
    r.feed(16, 1100);
    expect(r.d.recalibrations, 0);
    final disabled = Replay(seconds: 0);
    for (var i = 0; i < 12; i++) {
      disabled.cycle();
    }
    expect(disabled.d.recalibrations, 0);
  });

  test('model age and last reliable update age have distinct meanings', () {
    final r = Replay();
    r.dark(false);
    r.feed(20, 100);
    expect(r.d.modelAgeMs, greaterThan(10000));
    expect(r.d.baselineAgeMs, 0);
    r.dark(true);
    r.feed(16, 8);
    expect(r.d.baselineAgeMs, greaterThan(10000));
    final e = r.events.lastWhere(
      (e) => e['event'] == 'proximity' && e['reason'] == 'enter',
    );
    expect(e['baseline_age_ms'], greaterThan(10000));
  });
}
