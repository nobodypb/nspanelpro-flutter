import 'package:flutter_test/flutter_test.dart';

import 'proximity_recovery_test.dart' show Replay;

void main() {
  test('strong approach and touch followed by weak plateau recover after a fresh delay', () {
    final r = Replay();
    r.feed(50, 30);
    r.d.touch(r.now);
    r.feed(16, 1210);
    expect(r.d.recalibrations, 0);
    r.feed(16, 30);
    expect(r.d.recalibrations, 1);
    expect(r.d.near, false);
    expect(r.d.baseline, 16);
  });

  test('touch restarts the entire weak recovery interval while still near', () {
    final r = Replay();
    r.feed(16, 1100);
    r.d.touch(r.now);
    r.feed(16, 1199);
    expect(r.d.recalibrations, 0);
    r.feed(16, 3);
    expect(r.d.recalibrations, 1);
  });

  test('sensor gap resets evidence but does not prevent a fresh recovery', () {
    final r = Replay();
    r.feed(16, 1000);
    r.now += 180000;
    r.feed(16, 1199);
    expect(r.d.recalibrations, 0);
    r.feed(16, 3);
    expect(r.d.recalibrations, 1);
  });

  test(
    'brief weak samples and silence never release sustained strong presence',
    () {
      final r = Replay();
      r.feed(50, 30);
      for (var i = 0; i < 100; i++) {
        r.feed(16, 10);
        r.feed(50, 10);
      }
      r.now += 180000;
      r.feed(16, 1);
      r.feed(50, 1500);
      expect(r.d.recalibrations, 0);
      expect(r.d.near, true);
    },
  );
}
