import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/util/proximity_detector.dart';

class Trace {
  Trace({double factor = 4, bool adaptive = true})
    : d = ProximityDetector(adaptive: adaptive, noiseMultiplier: factor);
  final ProximityDetector d;
  int now = 0, entries = 0;
  void feed(double v, [int step = 100]) {
    now += step;
    d.advance(now);
    final was = d.near;
    d.feed(v, now);
    if (!was && d.near) entries++;
  }

  void quiet(int count, {double base = 20, double amplitude = 1}) {
    for (var i = 0; i < count; i++) {
      feed(base + [0, -1, 0, 1, 0, 1, 0, -1][i % 8] * amplitude);
    }
  }
}

void main() {
  test('quiet ambient allows a small approach that fixed delta misses', () {
    final adaptive = Trace(), fixed = Trace(adaptive: false);
    for (final t in [adaptive, fixed]) {
      t.quiet(300);
      t.feed(27);
      t.feed(27);
    }
    expect(adaptive.d.near, true);
    expect(fixed.d.near, false);
    expect(adaptive.d.threshold, lessThan(7));
  });

  test('factor controls the same approach without changing the baseline', () {
    final sensitive = Trace(factor: 2), guarded = Trace(factor: 6);
    for (final t in [sensitive, guarded]) {
      t.quiet(300);
      t.feed(25);
      t.feed(25);
    }
    expect(sensitive.d.near, true);
    expect(guarded.d.near, false);
  });

  test('slow daylight drift follows the baseline without waking', () {
    final t = Trace()..quiet(100);
    for (var i = 0; i < 3600; i++) {
      t.feed(20 + i / 300 + (i % 3 - 1));
    }
    expect(t.entries, 0);
    expect(t.d.baseline, closeTo(32, 1));
  });

  test('noise rises quickly, falls slowly, and quantisation keeps a floor', () {
    final t = Trace()..quiet(600);
    final quiet = t.d.threshold!;
    t.quiet(600, amplitude: 3);
    final noisy = t.d.threshold!;
    expect(noisy, greaterThan(quiet * 2));
    expect(t.entries, 0);
    t.quiet(100);
    expect(t.d.threshold, greaterThan(quiet * 1.5));
    t.quiet(3000, amplitude: 0);
    expect(t.d.threshold, closeTo(4, .3));
  });

  test('single spikes and opposite excursions do not confirm an approach', () {
    final t = Trace()..quiet(100);
    for (var i = 0; i < 30; i++) {
      t.feed(200);
      t.feed(-200);
      t.quiet(30);
    }
    expect(t.entries, 0);
    expect(t.d.threshold, lessThan(7));
    expect(t.d.baseline, closeTo(20, .2));
  });

  test('confirmed person never becomes the baseline or noise floor', () {
    final t = Trace()..quiet(100);
    t.feed(45);
    t.feed(45);
    final base = t.d.baseline, noise = t.d.noise;
    for (var i = 0; i < 600; i++) {
      t.feed(45 + (i % 2) * 30);
    }
    t.d.advance(t.now + 120000);
    expect(t.d.near, true);
    expect(t.d.baseline, base);
    expect(t.d.noise, noise);
    t.feed(20);
    t.d.advance(t.now + 499);
    expect(t.d.near, true);
    t.d.advance(t.now + 500);
    expect(t.d.near, false);
    t.quiet(100);
    t.feed(27);
    t.feed(27);
    expect(t.entries, 2);
  });

  test('noise can change abruptly and the detector can rearm', () {
    final t = Trace()..quiet(300);
    for (var i = 0; i < 1000; i++) {
      // Short bursts with repeated returns, not a permanent step/person.
      t.feed(20.0 + [6, 5, 0, 0, 0, 0, 0, 0, -6, -5, 0, 0, 0, 0, 0, 0][i % 16]);
    }
    expect(t.d.baseline, closeTo(20, 2));
    expect(t.entries, lessThan(30));
  });

  test(
    'display states learn separately and near transition is not learned',
    () {
      final t = Trace()..quiet(100, base: 40);
      t.d.dark(true);
      t.quiet(100, base: 12);
      expect(t.d.baseline, closeTo(12, .2));
      t.d.dark(false);
      expect(t.d.baseline, closeTo(40, .2));
      t.d.dark(true);
      t.feed(20);
      t.feed(20);
      expect(t.d.near, true);
      final d = ProximityDetector(adaptive: true);
      for (var i = 0; i < 30; i++) {
        d.feed(12, i * 100);
      }
      d.feed(24, 3000);
      d.feed(24, 3100);
      d.dark(true);
      d.feed(40, 3200);
      expect(d.near, true);
      expect(d.baseline, 12);
    },
  );

  test('invalid samples and long gaps cannot complete a stale candidate', () {
    final t = Trace()..quiet(100);
    t.feed(double.nan);
    t.feed(double.infinity);
    t.feed(28);
    t.feed(28, 5000);
    expect(t.d.near, false);
    t.feed(28);
    expect(t.d.near, true);
  });

  test('absolute thresholds take precedence over adaptive noise settings', () {
    final d = ProximityDetector(adaptive: true, above: 25, noiseMultiplier: 8);
    d.feed(26, 100);
    d.feed(26, 200);
    expect(d.near, true);
    expect(d.threshold, isNull);
    d.feed(19, 300);
    d.advance(800);
    expect(d.near, false);
  });

  test(
    'a weak permanent light step re-arms after stable continuous readings',
    () {
      final t = Trace()..quiet(100);
      t.quiet(290, base: 27);
      expect(t.d.near, true);
      t.quiet(50, base: 27);
      expect(t.d.near, false);
      expect(t.d.recalibrations, 1);
      expect(t.d.baseline, closeTo(27, .2));
      t.feed(34);
      t.feed(34);
      expect(t.d.near, true);
    },
  );

  test(
    'weak recovery can be disabled and sensor silence is not calibration',
    () {
      for (final delay in [0, 30]) {
        final d = ProximityDetector(adaptive: true, recalibrateSeconds: delay);
        for (var i = 0; i < 30; i++) {
          d.feed(20, i * 100);
        }
        d.feed(26, 3000);
        d.feed(26, 3100);
        d.advance(100000);
        expect(d.near, true);
        d.feed(26, 100100);
        expect(d.recalibrations, 0);
        if (delay == 0) {
          for (var i = 1; i < 1000; i++) {
            d.feed(26, 100100 + i * 100);
          }
          expect(d.near, true);
        }
      }
    },
  );

  test('gradual physical approach still crosses the learned rest level', () {
    final t = Trace()..quiet(100);
    for (var i = 1; i <= 60; i++) {
      t.feed(20 + i / 4);
    }
    expect(t.entries, 1);
    expect(t.d.baseline, lessThan(22));
  });
}
