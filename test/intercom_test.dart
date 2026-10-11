import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/intercom/intercom.dart';
import 'package:nspanel_app/util/navigation_controller.dart';

class FakeIntercom implements IntercomTransport {
  final stream = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final calls = <String>[];
  int id = 0;
  Completer<bool>? permissionReply;
  Completer<int>? openReply;
  bool allowed = true;
  @override
  Stream<Map<String, dynamic>> get events => stream.stream;
  void emit(String kind, {int? session}) =>
      stream.add({'kind': kind, 'session': session ?? id});
  @override
  Future<int> open(int session, Map<String, dynamic> profile) async {
    id = session;
    calls.add('open');
    return openReply == null ? 1 : await openReply!.future;
  }

  @override
  Future<bool> permission() async {
    calls.add('permission');
    return permissionReply == null ? allowed : await permissionReply!.future;
  }

  @override
  Future<void> microphone(int session, bool enabled) async {
    calls.add('mic:$enabled');
    emit(enabled ? 'talking' : 'muted', session: session);
  }

  @override
  Future<void> volume(int session, double value) async {
    calls.add('volume:$value');
  }

  @override
  Future<void> stop(int session) async {
    calls.add('stop:$session');
  }
}

void main() {
  late FakeIntercom transport;
  late IntercomController controller;
  late List<bool> holds;
  setUp(() {
    transport = FakeIntercom();
    holds = [];
    controller = IntercomController(transport, onBusy: holds.add);
  });
  tearDown(() async {
    controller.dispose();
    await transport.stream.close();
  });

  test('opening and preview never request or activate microphone', () async {
    await controller.open({});
    expect(holds, [true]);
    transport.emit('preview');
    expect(controller.state, IntercomState.preview);
    expect(holds, [true, false]);
    expect(transport.calls, ['open', 'volume:0.5']);
  });
  test('explicit speaking, mute, unmute and close release the hold', () async {
    await controller.open({});
    transport.emit('preview');
    await controller.speak();
    expect(controller.state, IntercomState.talking);
    await controller.mute();
    expect(controller.state, IntercomState.muted);
    expect(controller.busy, true);
    await controller.speak();
    expect(controller.state, IntercomState.talking);
    await controller.close();
    expect(controller.state, IntercomState.idle);
    expect(holds, [true, false, true, false]);
    expect(transport.calls.where((c) => c.startsWith('mic:')), [
      'mic:true',
      'mic:false',
      'mic:true',
    ]);
  });
  test(
    'permission denial retains hearing without microphone or call hold',
    () async {
      transport.allowed = false;
      await controller.open({});
      transport.emit('preview');
      await controller.speak();
      expect(controller.state, IntercomState.preview);
      expect(controller.error, 'permission');
      expect(controller.busy, false);
      expect(transport.calls, isNot(contains('mic:true')));
    },
  );
  test('late permission after close cannot activate microphone', () async {
    transport.permissionReply = Completer<bool>();
    await controller.open({});
    transport.emit('preview');
    final pending = controller.speak();
    await controller.close();
    transport.permissionReply!.complete(true);
    await pending;
    expect(transport.calls, isNot(contains('mic:true')));
    expect(controller.state, IntercomState.idle);
  });
  test(
    'duplicate starts and stale events cannot create or revive calls',
    () async {
      await controller.open({});
      final old = transport.id;
      await controller.open({});
      expect(transport.calls.where((c) => c == 'open').length, 1);
      transport.emit('preview');
      await controller.speak();
      transport.stream.add({'session': old, 'kind': 'error', 'reason': 'busy'});
      expect(controller.state, IntercomState.error);
      expect(controller.busy, false);
      await controller.open({});
      transport.emit('talking', session: old);
      expect(controller.state, IntercomState.opening);
      transport.emit('preview');
      expect(controller.state, IntercomState.preview);
      expect(transport.calls.where((c) => c == 'mic:true').length, 1);
    },
  );
  test('native background ends media without resuming microphone', () async {
    await controller.open({});
    transport.emit('preview');
    await controller.speak();
    transport.emit('ended');
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, IntercomState.idle);
    expect(controller.texture, isNull);
    expect(controller.busy, false);
  });
  test('late opening result is stopped after route closes', () async {
    transport.openReply = Completer<int>();
    final opening = controller.open({});
    await Future<void>.delayed(Duration.zero);
    final old = transport.id;
    await controller.close();
    transport.openReply!.complete(8);
    await opening;
    expect(controller.texture, isNull);
    expect(controller.state, IntercomState.idle);
    expect(transport.calls, contains('stop:$old'));
  });
  test('navigation holds block timers and external navigation; release renews deadline', () {
    int now = 0;
    final nav = PanelNavigation(now: () => now);
    nav.configure(
      count: 6,
      start: 2,
      after: 15,
      overrides: {5: 60},
      structure: 'test',
    );
    nav.navigate(5);
    final release = nav.hold();
    now = 120000;
    nav.check();
    expect(nav.current, 5);
    expect(nav.navigate(1), false);
    release();
    release();
    now += 59999;
    nav.check();
    expect(nav.current, 5);
    now++;
    nav.check();
    expect(nav.current, 2);
    nav.dispose();
  });
}
