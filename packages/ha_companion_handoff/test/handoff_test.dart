import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ha_companion_handoff/ha_companion_handoff.dart';

class Fake implements HandoffTransport {
  final bus = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  int starts = 0, returns = 0, finishes = 0;
  bool fail = false;
  @override
  Stream<Map<String, dynamic>> get events => bus.stream;
  @override
  Future<bool> available() async => true;
  @override
  Future<void> begin() async {
    starts++;
    if (fail) throw StateError('failed');
  }

  @override
  Future<void> prepared(String id) async {
    returns++;
  }

  @override
  Future<void> finish(String id) async {
    finishes++;
  }

  void emit(String state, {String id = 'one', bool dark = false}) =>
      bus.add({'state': state, 'session': id, 'dark': dark});
}

void main() {
  test(
    'one launch, dark return, stale events ignored, explicit release',
    () async {
      final f = Fake();
      int takes = 0, drops = 0;
      final darks = <bool>[];
      final c = HandoffController(
        f,
        acquire: () => takes++,
        release: () => drops++,
        prepareReturn: (dark) async {
          darks.add(dark);
        },
      );
      await c.check();
      await c.begin();
      await c.begin();
      f.emit('external');
      f.emit('returning', id: 'stale', dark: true);
      await Future<void>.delayed(Duration.zero);
      expect(f.returns, 0);
      f.emit('returning', dark: true);
      await Future<void>.delayed(Duration.zero);
      expect(f.returns, 1);
      expect(c.active, true);
      expect(drops, 0);
      f.emit('resumed', dark: true);
      await Future<void>.delayed(Duration.zero);
      expect(f.starts, 1);
      expect(takes, 1);
      expect(drops, 1);
      expect(f.finishes, 1);
      expect(c.active, false);
      expect(darks, [true, true]);
      f.emit('resumed', dark: true);
      await Future<void>.delayed(Duration.zero);
      expect(takes, 1);
      expect(f.finishes, 1);
      c.dispose();
      await f.bus.close();
    },
  );
  test('failed launch releases host and permits retry', () async {
    final f = Fake()..fail = true;
    int drops = 0;
    final c = HandoffController(
      f,
      acquire: () {},
      release: () => drops++,
      prepareReturn: (_) async {},
    );
    await c.check();
    await c.begin();
    expect(c.active, false);
    expect(c.error, isNotNull);
    expect(drops, 1);
    f.fail = false;
    await c.begin();
    expect(f.starts, 2);
    expect(c.error, isNull);
    c.dispose();
    await f.bus.close();
  });
  test('native recovery before user starts reacquires host', () async {
    final f = Fake();
    int takes = 0, drops = 0;
    final c = HandoffController(
      f,
      acquire: () => takes++,
      release: () => drops++,
      prepareReturn: (_) async {},
    );
    f.emit('returning', dark: true);
    await Future<void>.delayed(Duration.zero);
    expect(takes, 1);
    expect(f.starts, 0);
    expect(f.returns, 1);
    f.emit('resumed');
    await Future<void>.delayed(Duration.zero);
    expect(drops, 1);
    c.dispose();
    await f.bus.close();
  });
  test('display hold refusal never launches companion', () async {
    final f = Fake();
    final c = HandoffController(
      f,
      acquire: () => throw StateError('held'),
      release: () {},
      prepareReturn: (_) async {},
    );
    await c.check();
    await c.begin();
    expect(f.starts, 0);
    expect(c.active, false);
    expect(c.error, isNotNull);
    c.dispose();
    await f.bus.close();
  });
}
