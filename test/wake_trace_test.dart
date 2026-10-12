import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/config/screensaver.dart';
import 'package:nspanel_app/util/display_controller.dart';

import 'display_controller_test.dart' show Driver;

void main() {
  test('wake intent preserves provenance and records existing suppression', () {
    final events = <Map<String, Object?>>[];
    final c = DisplayController(
      Driver(),
      onTrace: (event, fields) => events.add({'event': event, ...fields}),
    );
    c.configure(
      const ScreensaverConfig(afterSeconds: 15, sleep: true),
      active: true,
    );
    c.platform(
      kind: 'screen',
      screenOn: false,
      inForeground: true,
      pointerCount: 0,
    );
    c.proximity(true);
    expect(events.last, containsPair('reason', 'proximity'));
    expect(events.last, containsPair('dark', true));
    c.wake(reason: 'touch');
    expect(events.last['reason'], 'touch');
    c.wake(reason: 'mqtt');
    expect(events.last['reason'], 'mqtt');
    final release = c.hold(reason: 'ring');
    expect(events.last['reason'], 'ring');
    release();
    c.platform(
      kind: 'screen',
      screenOn: true,
      inForeground: true,
      pointerCount: 0,
    );
    c.platform(
      kind: 'screen',
      screenOn: false,
      inForeground: true,
      pointerCount: 0,
    );
    // A forced sleep during existing proximity blocks that same approach.
    c.proximity(false);
    c.proximity(true);
    c.sleep(force: true);
    expect(events.last['decision'], 'near_blocked');
    c.configure(const ScreensaverConfig(wakeOnProximity: false), active: true);
    c.proximity(false);
    c.proximity(true);
    expect(events.last['accepted'], false);
    expect(events.last['decision'], 'disabled');
    c.dispose();
  });
}
