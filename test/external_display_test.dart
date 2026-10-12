import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/util/display_controller.dart';

import 'display_controller_test.dart' show Driver, config, touch;

void main() {
  testWidgets('external session defers idle, preserves near and returns dark', (
    t,
  ) async {
    final d = Driver();
    final c = DisplayController(d)..configure(config, active: true);
    touch(c, 0);
    c.proximity(true);
    final lease = c.beginExternalSession();
    touch(c, 0, foreground: false);
    await t.pump(const Duration(seconds: 60));
    expect(d.offs, 0);
    expect(d.ons, 0);
    expect(c.near, true);
    touch(c, 0, on: false, foreground: false);
    await lease.prepareReturn(dark: true);
    expect(c.foreground, false);
    expect(c.saving, true);
    expect(d.cpu, true);
    c.proximity(true);
    await t.pump();
    expect(d.ons, 0);
    c.proximity(false);
    c.proximity(true);
    await t.pump();
    expect(d.ons, 1);
    touch(c, 0, foreground: true);
    lease.release();
    lease.release();
    expect(c.externalSession, false);
    c.proximity(false);
    await t.pump(const Duration(seconds: 16));
    expect(d.offs, 1);
    c.dispose();
  });
  testWidgets(
    'release in the dark does not wake and activity state is truthful',
    (t) async {
      final d = Driver();
      final c = DisplayController(d)..configure(config, active: true);
      touch(c, 0);
      final lease = c.beginExternalSession();
      touch(c, 0, on: false, foreground: false);
      await lease.prepareReturn(dark: true);
      c.platform(
        kind: 'lifecycle',
        screenOn: false,
        inForeground: true,
        pointerCount: 0,
      );
      lease.release();
      await t.pump(const Duration(seconds: 60));
      expect(d.ons, 0);
      expect(c.saving, true);
      c.proximity(true);
      await t.pump();
      expect(d.ons, 1);
      c.dispose();
    },
  );
  testWidgets('holds reject handoff and failed launch restores idle', (
    t,
  ) async {
    final d = Driver();
    final c = DisplayController(d)..configure(config, active: true);
    touch(c, 0);
    final release = c.hold();
    expect(c.beginExternalSession, throwsStateError);
    release();
    final lease = c.beginExternalSession();
    expect(c.beginExternalSession, throwsStateError);
    lease.release();
    await t.pump(const Duration(seconds: 16));
    expect(d.offs, 1);
    c.dispose();
  });
}
