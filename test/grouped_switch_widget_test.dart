import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/cards/env.dart';
import 'package:nspanel_app/cards/switch_card.dart';
import 'package:nspanel_app/cards/switch_sheet.dart';
import 'package:nspanel_app/config/settings.dart';
import 'package:nspanel_app/ha/connection.dart';
import 'package:nspanel_app/ha/states.dart';

import 'connection_test.dart' show FakeHa, st;

void main() {
  testWidgets('ten grouped sockets fit and retain tap and detail actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = FakeHa({
      for (var i = 1; i <= 10; i++)
        'switch.socket$i': st('switch.socket$i', 'off'),
    });
    final states = HaStates();
    final conn = HaConnection(
      transportFactory: () async => fake,
      token: 'good',
      states: states,
    );
    final ready = Completer<void>();
    conn.onReady = ready.complete;
    await conn.start();
    await ready.future;
    addTearDown(() {
      unawaited(conn.dispose());
    });

    final groups = [
      for (final (name, first, count) in [
        ('Essen', 1, 4),
        ('Küche', 5, 2),
        ('Wohnen', 7, 4),
      ])
        {
          'name': name,
          'switches': [
            for (var i = first; i < first + count; i++)
              {
                'entity': 'switch.socket$i',
                'name': 'Dose $i',
                'circuit': 'P$i · SW',
              },
          ],
        },
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: SwitchCard(
              config: {'height': 442, 'groups': groups},
              env: PanelEnv(
                states: states,
                conn: conn,
                settings: Settings(url: 'http://fake', token: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Dose 10'), findsOneWidget);
    expect(find.text('P10 · SW'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final target = find
        .ancestor(
          of: find.text('Dose 10'),
          matching: find.byType(GestureDetector),
        )
        .first;
    expect(tester.getSize(target).height, greaterThanOrEqualTo(56));
    expect(tester.getSize(target).width, greaterThanOrEqualTo(56));

    await tester.tap(find.text('Dose 10'));
    await tester.pump();
    expect(
      fake.calls.last,
      'homeassistant.turn_on {"entity_id":"switch.socket10"}',
    );
    final calls = fake.calls.length;
    await tester.longPress(find.text('Dose 1'));
    await tester.pumpAndSettle();
    expect(find.byType(SwitchSheet), findsOneWidget);
    expect(fake.calls.length, calls);
  });
}
