import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:doorbird_intercom/doorbird_intercom.dart';

import 'support/fake_intercom.dart';

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
  test(
    'ring mixes without altering microphone, gain or conversation holds',
    () async {
      await controller.open({});
      transport.emit('preview');
      await controller.ring(.6);
      expect(controller.state, IntercomState.preview);
      await controller.speak();
      await controller.ring(.2);
      expect(controller.state, IntercomState.talking);
      await controller.mute();
      await controller.ring(.2);
      expect(controller.state, IntercomState.muted);
      expect(controller.volume, .5);
      expect(transport.calls.where((c) => c.startsWith('ring:')), [
        'ring:0.6',
        'ring:0.2',
        'ring:0.2',
      ]);
      expect(transport.calls.where((c) => c.startsWith('mic:')), [
        'mic:true',
        'mic:false',
      ]);
      expect(holds, [true, false, true]);
    },
  );
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
}
