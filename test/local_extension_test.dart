import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/local/doorbird/extension.dart';

import '../packages/doorbird_intercom/test/support/fake_intercom.dart';

void main() {
  testWidgets('adapter owns paired holds and exposes an optional camera view', (
    tester,
  ) async {
    final transport = FakeIntercom();
    var displayHolds = 0, navigationHolds = 0;
    final extension = DoorBirdExtension(
      transport: transport,
      beforeMedia: () async {},
      holdDisplay: () {
        displayHolds++;
        return () => displayHolds--;
      },
      holdNavigation: () {
        navigationHolds++;
        return () => navigationHolds--;
      },
    );
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      extension.build(context, {'entity': 'camera.test'}, const SizedBox()),
      isNull,
    );
    expect(
      extension.build(context, {
        'intercom': {'profile': ''},
      }, const SizedBox()),
      isNull,
    );
    await extension.controller.open({});
    expect(extension.suspendsStillImages, true);
    expect([displayHolds, navigationHolds], [1, 1]);
    transport.emit('preview');
    expect([displayHolds, navigationHolds], [0, 0]);
    await extension.controller.speak();
    expect([displayHolds, navigationHolds], [1, 1]);
    extension.dispose();
    expect([displayHolds, navigationHolds], [0, 0]);
    await transport.stream.close();
  });

  testWidgets('late private profile read cannot open a disposed extension', (
    tester,
  ) async {
    final transport = FakeIntercom();
    final profile = Completer<Map<String, dynamic>>();
    final extension = DoorBirdExtension(
      transport: transport,
      beforeMedia: () async {},
      holdDisplay: () => () {},
      holdNavigation: () => () {},
      loadProfile: (_) => profile.future,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => extension.build(context, {
            'intercom': {'profile': 'test'},
          }, const SizedBox())!,
        ),
      ),
    );
    await tester.tap(find.text('Live'));
    await tester.pumpWidget(const SizedBox());
    extension.dispose();
    profile.complete({});
    await tester.pumpAndSettle();
    expect(transport.calls.where((x) => x == 'open'), isEmpty);
    expect(find.text('DoorBird'), findsNothing);
    expect(tester.takeException(), isNull);
    await transport.stream.close();
  });
}
