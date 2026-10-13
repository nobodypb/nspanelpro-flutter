import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/local/doorbird/extension.dart';
import 'package:nspanel_app/local/doorbird/ringtone.dart';
import 'package:nspanel_app/ui/page_scope.dart';
import 'package:nspanel_app/util/navigation_controller.dart';

import '../packages/doorbird_intercom/test/support/fake_intercom.dart';

class _Tone implements DoorBirdRingtone {
  final gate = Completer<void>();
  int plays = 0;
  @override
  Future<void> play() {
    plays++;
    return gate.future;
  }

  @override
  Future<void> wait() => gate.future;
  @override
  Future<void> stop() async {
    if (!gate.isCompleted) gate.complete();
  }

  @override
  Future<void> dispose() => stop();
}

void main() {
  for (final mode in ['preview', 'talking', 'muted']) {
    test(
      'full-volume ring preserves $mode media and microphone state',
      () async {
        final media = FakeIntercom();
        final tone = _Tone()..gate.complete();
        final shown = ValueNotifier(0);
        final navigation = PanelNavigation();
        navigation.configure(
          count: 4,
          start: 3,
          after: 15,
          overrides: {0: 60},
          structure: 'test',
        );
        final extension = DoorBirdExtension(
          transport: media,
          ringtone: tone,
          navigation: navigation,
          shownPage: shown,
          foreground: () => true,
          canShow: (page) => page == 0,
          holdDisplay: () => () {},
          holdNavigation: navigation.hold,
          beforeMedia: () async {},
        );
        await extension.controller.open({});
        media.emit('preview');
        if (mode != 'preview') await extension.controller.speak();
        if (mode == 'muted') await extension.controller.mute();
        final state = extension.controller.state;
        media.calls.clear();
        extension.rings!.command({
          'type': 'doorbird.ring',
          'page': 0,
          'event_id': DateTime.now().toUtc().toIso8601String(),
        });
        await Future<void>.delayed(Duration.zero);
        expect(media.calls, ['ring:1.0']);
        expect(extension.controller.state, state);
        expect(tone.plays, 0);
        extension.dispose();
        navigation.dispose();
        shown.dispose();
        await media.stream.close();
      },
    );
  }

  testWidgets(
    'ring orders tone before auto live and returns with microphone off',
    (tester) async {
      final media = FakeIntercom();
      final tone = _Tone();
      final shown = ValueNotifier(3), awake = ValueNotifier(true);
      var now = DateTime.now().millisecondsSinceEpoch;
      final navigation = PanelNavigation(now: () => now);
      navigation.configure(
        count: 4,
        start: 3,
        after: 15,
        overrides: {0: 60},
        structure: 'test',
      );
      navigation.addListener(() {
        shown.value = navigation.target ?? navigation.current;
      });
      var display = 0, ringHolds = 0;
      final extension = DoorBirdExtension(
        transport: media,
        ringtone: tone,
        navigation: navigation,
        shownPage: shown,
        foreground: () => true,
        canShow: (page) => page == 0,
        holdDisplay: () {
          display++;
          return () => display--;
        },
        holdRingDisplay: () {
          display++;
          ringHolds++;
          return () {
            display--;
            ringHolds--;
          };
        },
        holdNavigation: navigation.hold,
        beforeMedia: () async {},
        loadProfile: (_) async => {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PageScope(
            index: 0,
            shown: shown,
            awake: awake,
            child: Builder(
              builder: (context) => extension.build(context, {
                'entity': 'camera.test',
                'intercom': {'profile': 'test', 'auto_live': true},
              }, const SizedBox())!,
            ),
          ),
        ),
      );
      extension.rings!.command({
        'type': 'doorbird.ring',
        'page': 0,
        'event_id': DateTime.now().toUtc().toIso8601String(),
      });
      await tester.pump();
      await tester.pump();
      expect(tone.plays, 1);
      expect(ringHolds, 1);
      expect(media.calls, isEmpty);
      expect(navigation.held, false);
      tone.gate.complete();
      await tester.pump();
      media.emit('preview');
      await tester.pump();
      expect(media.calls.where((c) => c == 'open').length, 1);
      expect(display, 1);
      now += 60000;
      navigation.check();
      await tester.pump();
      expect(navigation.current, 3);
      expect(display, 0);
      expect(ringHolds, 0);
      expect(media.calls.where((c) => c == 'mic:true'), isEmpty);
      expect(media.calls.any((c) => c.startsWith('stop:')), true);
      await tester.pumpWidget(const SizedBox());
      extension.dispose();
      navigation.dispose();
      shown.dispose();
      awake.dispose();
      await media.stream.close();
    },
  );
}
