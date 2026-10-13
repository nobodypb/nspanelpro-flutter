import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/cards/env.dart';
import 'package:nspanel_app/cards/frequent_card.dart';
import 'package:nspanel_app/cards/light_card.dart';
import 'package:nspanel_app/config/dashboard.dart';
import 'package:nspanel_app/config/settings.dart';
import 'package:nspanel_app/ha/connection.dart';
import 'package:nspanel_app/ha/states.dart';
import 'package:nspanel_app/ui/page_scope.dart';
import 'package:nspanel_app/util/usage_candidates.dart';
import 'package:nspanel_app/util/usage_history.dart';

void main() {
  testWidgets('opening an original light dialog records one event', (t) async {
    final usage = UsageHistory(now: () => 1800000000000);
    final states = HaStates()
      ..replaceAll({
        'light.desk': const HaState(
          entityId: 'light.desk',
          state: 'on',
          attributes: {
            'supported_color_modes': ['brightness'],
            'brightness': 128,
          },
        ),
      });
    final conn = HaConnection(
      transportFactory: () async => throw StateError('not used'),
      token: 'fake',
      states: states,
    );
    final env = PanelEnv(
      states: states,
      conn: conn,
      settings: Settings(url: 'http://fake', token: 'fake'),
      usage: usage,
    );
    final shown = ValueNotifier<int>(0), awake = ValueNotifier<bool>(true);
    addTearDown(() {
      shown.dispose();
      awake.dispose();
      usage.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageScope(
            index: 0,
            shown: shown,
            awake: awake,
            child: LightCard(
              config: const {
                'entity': 'light.desk',
                'height': 216,
                'swap_press_actions': true,
              },
              env: env,
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byType(LightCard));
    await t.pumpAndSettle();
    expect(usage.events.length, 1);
    expect(usage.events.single.gesture, 'tap');
    expect(usage.events.single.result, 'detail');
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'filtered recommendations fit 480 square and do not count their own taps',
    (t) async {
      t.view.physicalSize = const Size(480, 480);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      const now = 1800000000000;
      final usage = UsageHistory(now: () => now);
      usage.record(
        'light.desk',
        'nspanel-light-card',
        0,
        'tap',
        result: 'detail',
      );
      usage.record(
        'cover.blind',
        'nspanel-cover-card',
        0,
        'tap',
        result: 'success',
      );
      usage.record(
        'light.bath',
        'nspanel-light-card',
        1,
        'tap',
        result: 'detail',
      );
      final pages = [
        PanelPage([
          {
            'type': 'custom:nspanel-light-card',
            'entity': 'light.desk',
            'title': 'Desk',
          },
          {
            'type': 'custom:nspanel-cover-card',
            'entity': 'cover.blind',
            'title': 'Blind',
          },
        ]),
        PanelPage([
          {
            'type': 'custom:nspanel-light-card',
            'entity': 'light.bath',
            'title': 'Bath',
          },
          {'type': 'custom:nspanel-frequent-card', 'count': 3},
        ]),
      ];
      final states = HaStates()
        ..replaceAll({
          'light.desk': const HaState(
            entityId: 'light.desk',
            state: 'on',
            attributes: {},
          ),
          'light.bath': const HaState(
            entityId: 'light.bath',
            state: 'on',
            attributes: {},
          ),
          'cover.blind': const HaState(
            entityId: 'cover.blind',
            state: 'open',
            attributes: {},
          ),
        });
      final conn = HaConnection(
        transportFactory: () async => throw StateError('not used'),
        token: 'fake',
        states: states,
      );
      final env = PanelEnv(
        states: states,
        conn: conn,
        settings: Settings(url: 'http://fake', token: 'fake'),
        usage: usage,
        usageCandidates: () => usageCandidates(pages),
      );
      final shown = ValueNotifier<int>(1), awake = ValueNotifier<bool>(true);
      addTearDown(() {
        shown.dispose();
        awake.dispose();
        usage.dispose();
      });
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageScope(
              index: 1,
              shown: shown,
              awake: awake,
              child: Column(
                children: [
                  const SizedBox(height: 216),
                  const SizedBox(height: 12),
                  const SizedBox(height: 76),
                  const SizedBox(height: 12),
                  FrequentCard(
                    config: const {
                      'count': 3,
                      'entity_domains': ['light'],
                    },
                    env: env,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Desk'), findsOneWidget);
      expect(find.text('Blind'), findsNothing);
      expect(find.text('Bath'), findsNothing);
      final target = find
          .ancestor(
            of: find.text('Desk'),
            matching: find.byType(GestureDetector),
          )
          .first;
      expect(t.getSize(target).height, greaterThanOrEqualTo(56));
      expect(t.getSize(target).width, greaterThanOrEqualTo(56));
      expect(t.takeException(), isNull);
      await t.tap(find.text('Desk'));
      await t.pump();
      expect(usage.events.length, 3);
    },
  );
}
