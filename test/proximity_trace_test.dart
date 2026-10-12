import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/util/proximity_detector.dart';

void main() {
  test('records calibration values and the configured 120 second recovery', () {
    final events = <Map<String, Object?>>[];
    final d = ProximityDetector(
      adaptive: true,
      noiseMultiplier: 3,
      recalibrateSeconds: 120,
      onTrace: (event, fields) => events.add({'event': event, ...fields}),
    );
    final reference = ProximityDetector(
      adaptive: true,
      noiseMultiplier: 3,
      recalibrateSeconds: 120,
    );
    for (var now = 0; now <= 123100; now += 100) {
      final value = now < 3000 ? 20.0 : 24.0;
      d.feed(value, now);
      reference.feed(value, now);
      expect(d.near, reference.near);
      expect(d.baseline, reference.baseline);
      expect(d.threshold, reference.threshold);
      if (now < 123100) expect(d.recalibrations, 0);
    }
    final calibrations = events
        .where((e) => e['event'] == 'calibration')
        .toList();
    expect(calibrations, hasLength(2));
    expect(calibrations.first['reason'], 'initial');
    expect(calibrations.first['old_baseline'], isNull);
    expect(calibrations.last, containsPair('reason', 'weak_stable'));
    expect(calibrations.last['old_baseline'], 20);
    expect(calibrations.last['baseline'], 24);
    expect(calibrations.last['delay_seconds'], 120);
    expect(calibrations.last['detector_ms'], 123100);
    expect(events.last['reason'], 'recalibrated_leave');
  });

  test('separate display calibrations and debounced leave are logged once', () {
    final events = <Map<String, Object?>>[];
    final d = ProximityDetector(
      adaptive: true,
      onTrace: (event, fields) => events.add({'event': event, ...fields}),
    );
    for (var i = 0; i < 30; i++) {
      d.feed(20, i * 100);
    }
    d.dark(true);
    for (var i = 30; i < 60; i++) {
      d.feed(10, i * 100);
    }
    d.feed(30, 6000);
    d.feed(30, 6100);
    d.feed(10, 6200);
    d.advance(6700);
    d.advance(6800);
    expect(events.map((e) => e['reason']), [
      'initial',
      'initial',
      'enter',
      'leave',
    ]);
    expect(events[1]['dark'], true);
    expect(events[1]['baseline'], 10);
  });
}
