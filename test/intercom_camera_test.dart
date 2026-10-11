import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/local/doorbird/extension.dart';
import 'package:nspanel_app/cards/camera_card.dart';
import 'package:nspanel_app/cards/env.dart';
import 'package:nspanel_app/config/settings.dart';
import 'package:nspanel_app/ha/connection.dart';
import 'package:nspanel_app/ha/states.dart';
import 'package:nspanel_app/ui/page_scope.dart';
import 'package:nspanel_app/ui/sheet.dart';

import '../packages/doorbird_intercom/test/support/fake_intercom.dart';

const config = <String, dynamic>{
  'entity': 'camera.test',
  'intercom': {'profile': 'test'},
  'fit': 'contain',
};

void main() {
  testWidgets(
    'fixed image and four bottom targets from still to live and back',
    (tester) async {
      tester.view.physicalSize = const Size(480, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transport = FakeIntercom();
      final extension = DoorBirdExtension(
        transport: transport,
        beforeMedia: () async {},
        loadProfile: (_) async => {},
        holdDisplay: () => () {},
        holdNavigation: () => () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: Builder(
                builder: (context) => SizedBox(
                  height: 444,
                  child: extension.build(
                    context,
                    config,
                    const ColoredBox(
                      key: ValueKey('still'),
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final picture = find.byKey(const ValueKey('camera-picture'));
      final original = tester.getRect(picture);
      expect(original.size, const Size(456, 336));
      final initialButtons = find
          .byType(SheetButton)
          .evaluate()
          .map((e) => tester.getRect(find.byWidget(e.widget)))
          .toList();
      expect(initialButtons.length, 4);
      for (final rect in initialButtons) {
        expect(rect.size, const Size(108, 76));
        expect(rect.top, greaterThan(original.bottom));
      }
      expect(find.text('Standbild · Mikrofon aus'), findsOneWidget);
      await tester.tap(find.text('Sprechen'));
      await tester.tap(find.text('Lauter'));
      expect(transport.calls, isEmpty);
      await tester.tap(find.text('Live'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('still')),
        findsOneWidget,
        reason: 'keep still until a decoded live frame exists',
      );
      transport.emit('preview');
      transport.stream.add({
        'kind': 'metrics',
        'session': transport.id,
        'video_frames': 1,
      });
      await tester.pump();
      expect(find.byType(Texture), findsOneWidget);
      expect(find.byKey(const ValueKey('still')), findsNothing);
      expect(transport.calls, isNot(contains('mic:true')));
      expect(tester.getRect(picture), original);
      expect(
        find
            .byType(SheetButton)
            .evaluate()
            .map((e) => tester.getRect(find.byWidget(e.widget)))
            .toList(),
        initialButtons,
      );
      await tester.tap(find.text('Lauter'));
      await tester.pump();
      expect(transport.calls, contains('volume:0.55'));
      await tester.tap(find.text('Sprechen'));
      await tester.pump();
      expect(find.text('Gespräch · Mikrofon an'), findsOneWidget);
      await tester.tap(find.text('Stumm'));
      await tester.pump();
      expect(find.text('Gespräch · Mikrofon aus'), findsOneWidget);
      await tester.tap(find.text('Beenden'));
      await tester.pump();
      expect(find.text('Standbild · Mikrofon aus'), findsOneWidget);
      expect(tester.getRect(picture), original);
      expect(find.byKey(const ValueKey('still')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      extension.dispose();
      await transport.stream.close();
    },
  );

  testWidgets('camera polling resumes in place after live ends', (
    tester,
  ) async {
    final transport = FakeIntercom();
    final extension = DoorBirdExtension(
      transport: transport,
      beforeMedia: () async {},
      loadProfile: (_) async => {},
      holdDisplay: () => () {},
      holdNavigation: () => () {},
    );
    final states = HaStates();
    final conn = HaConnection(
      token: 'test',
      states: states,
      transportFactory: () async =>
          throw StateError('No network in widget test'),
    );
    final env = PanelEnv(
      states: states,
      conn: conn,
      settings: Settings(url: 'http://unused', token: 'test'),
      cameraInteraction: extension,
    );
    var fetched = 0;
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CameraCard(
            config: {...config, 'height': 444},
            env: env,
            fetch: (_, _, _) async {
              fetched++;
              return png;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(fetched, 1);
    await tester.tap(find.text('Live'));
    await tester.pump();
    transport.emit('preview');
    await tester.pump(const Duration(seconds: 2));
    expect(fetched, 1, reason: 'no HA camera requests during media');
    await tester.tap(find.text('Beenden'));
    await tester.pump();
    expect(fetched, 2);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Standbild · Mikrofon aus'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    extension.dispose();
    await transport.stream.close();
    unawaited(conn.dispose());
  });

  for (final pending in [false, true]) {
    testWidgets(
      'page departure cancels ${pending ? 'pending profile' : 'live session'} without auto restart',
      (tester) async {
        final transport = FakeIntercom();
        final profile = Completer<Map<String, dynamic>>();
        final shown = ValueNotifier(0);
        final awake = ValueNotifier(true);
        var holds = 0;
        final extension = DoorBirdExtension(
          transport: transport,
          beforeMedia: () async {},
          loadProfile: (_) => pending ? profile.future : Future.value({}),
          holdDisplay: () {
            holds++;
            return () => holds--;
          },
          holdNavigation: () {
            holds++;
            return () => holds--;
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: PageScope(
              index: 0,
              shown: shown,
              awake: awake,
              child: Builder(
                builder: (context) =>
                    extension.build(context, config, const SizedBox())!,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Live'));
        await tester.pump();
        if (!pending) {
          transport.emit('preview');
          await tester.pump();
          await tester.tap(find.text('Sprechen'));
          await tester.pump();
          expect(holds, 2);
        }
        shown.value = 1;
        if (pending) profile.complete({});
        await tester.pump();
        expect(extension.controller.inUse, false);
        expect(holds, 0);
        final opens = transport.calls.where((c) => c == 'open').length;
        expect(opens, pending ? 0 : 1);
        shown.value = 0;
        await tester.pump();
        expect(find.text('Standbild · Mikrofon aus'), findsOneWidget);
        expect(transport.calls.where((c) => c == 'open').length, opens);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        extension.dispose();
        await transport.stream.close();
        shown.dispose();
        awake.dispose();
      },
    );
  }
}
