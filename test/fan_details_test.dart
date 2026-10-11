import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/cards/env.dart';
import 'package:nspanel_app/cards/fan_capabilities.dart';
import 'package:nspanel_app/cards/fan_sheet.dart';
import 'package:nspanel_app/cards/switch_card.dart';
import 'package:nspanel_app/config/settings.dart';
import 'package:nspanel_app/ha/connection.dart';
import 'package:nspanel_app/ha/states.dart';
import 'package:nspanel_app/ui/theme.dart';
import 'package:nspanel_app/ui/sheet.dart';
import 'package:nspanel_app/cards/light_card.dart';

import 'connection_test.dart' show FakeHa, st;

/// Service acknowledgement is separate from state, as with a real appliance.
class FanHa extends FakeHa {
  FanHa(super.states) {
    super.messages.listen(_results.add);
  }
  final _results = StreamController<String>();
  bool refuses = false;
  bool delay = false;
  @override
  Stream<String> get messages => _results.stream;
  @override
  void send(String raw) {
    final msg = jsonDecode(raw) as Map<String, dynamic>;
    if (msg['type'] != 'call_service') {
      super.send(raw);
      return;
    }
    sent.add(msg);
    calls.add(
      '${msg['domain']}.${msg['service']} ${jsonEncode(msg['service_data'])}',
    );
    if (!delay) respond(msg['id'] as int);
  }

  void respond(int id) => _results.add(
    jsonEncode({
      'id': id,
      'type': 'result',
      'success': !refuses,
      if (refuses) 'error': {'code': 'test', 'message': 'Refused'},
      'result': null,
    }),
  );
  @override
  Future<void> close() async {
    await super.close();
    await _results.close();
  }
}

const fanId = 'fan.test';
HaState fan(Map<String, dynamic> attributes, {String state = 'off'}) => HaState(
  entityId: fanId,
  state: state,
  attributes: {'friendly_name': 'Test fan', ...attributes},
);

Future<(FanHa, HaStates, HaConnection)> mount(
  WidgetTester tester, {
  Map<String, dynamic> attributes = const {'supported_features': 49},
  String state = 'off',
  bool moreInfo = true,
}) async {
  tester.view.physicalSize = const Size(480, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final fake = FanHa({
    fanId: st(fanId, state, {'friendly_name': 'Test fan', ...attributes}),
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
  addTearDown(() => unawaited(conn.dispose()));
  await tester.pumpWidget(
    MaterialApp(
      theme: Ns.theme(),
      home: Scaffold(
        body: PageView(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SwitchCard(
                config: {'entity': fanId, 'height': 160, 'more_info': moreInfo},
                env: PanelEnv(
                  states: states,
                  conn: conn,
                  settings: Settings(url: 'http://fake', token: 'test'),
                ),
              ),
            ),
            const Center(child: Text('Next page')),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return (fake, states, conn);
}

Future<void> open(WidgetTester tester) async {
  await tester.longPress(find.text('Test fan'));
  await tester.pumpAndSettle();
  expect(find.byType(FanSheet), findsOneWidget);
}

void main() {
  test(
    'capabilities are independent and malformed attributes are conservative',
    () {
      final hood = FanCapabilities(
        fan({'supported_features': 17, 'percentage_step': 20}),
      );
      expect(hood.speed, isTrue);
      expect(hood.turnOff, isTrue);
      expect(hood.turnOn, isFalse);
      expect(hood.presets, isEmpty);
      expect(hood.levels, [0, 20, 40, 60, 80, 100]);
      for (final flags in [null, '49', -1, double.nan, double.infinity]) {
        final caps = FanCapabilities(fan({'supported_features': flags}));
        expect(caps.speed || caps.turnOn || caps.turnOff, isFalse);
      }
      for (final step in [
        null,
        '20',
        0,
        -1,
        double.nan,
        double.infinity,
        101,
        1e-300,
      ]) {
        expect(
          FanCapabilities(fan({'percentage_step': step})).levels.length,
          101,
        );
      }
      expect(FanCapabilities(fan({'percentage_step': 100 / 3})).levels, [
        0,
        33,
        66,
        100,
      ]);
      expect(hood.snap(-10), 0);
      expect(hood.snap(47), 40);
      expect(hood.snap(900), 100);
      expect(hood.snap(double.nan), 0);
      expect(
        FanCapabilities(
          fan({
            'supported_features': 8,
            'preset_modes': ['auto', null, '', 'auto'],
          }),
        ).presets,
        ['auto'],
      );
      expect(
        FanCapabilities(
          fan({
            'supported_features': 1,
            'preset_modes': ['auto'],
          }),
        ).presets,
        ['auto'],
      );
      expect(
        FanCapabilities(
          fan({
            'supported_features': 0,
            'preset_modes': ['auto'],
          }),
        ).presets,
        isEmpty,
      );
    },
  );

  Finder control(String name) => find.byKey(ValueKey('sheet-$name'));
  ControlSheet sheet(WidgetTester t) =>
      t.widget<ControlSheet>(find.byType(ControlSheet));
  Future<void> close(WidgetTester t) async {
    await t.tap(control('close'));
    await t.pumpAndSettle();
  }

  testWidgets(
    'hold and close are service-free; standalone short tap still powers fan',
    (t) async {
      final (fake, _, _) = await mount(t);
      await open(t);
      expect(fake.calls, isEmpty);
      await close(t);
      expect(fake.calls, isEmpty);
      await t.tap(find.text('Test fan'));
      await t.pump();
      expect(fake.calls, ['fan.turn_on {"entity_id":"fan.test"}']);
    },
  );

  testWidgets('hood tap opens shared sheet without unsupported power on', (
    t,
  ) async {
    final (fake, _, _) = await mount(
      t,
      attributes: {'supported_features': 17, 'percentage_step': 20},
    );
    await t.tap(find.text('Test fan'));
    await t.pumpAndSettle();
    expect(find.byType(ControlSheet), findsOneWidget);
    expect(find.text('Turn on'), findsNothing);
    expect(fake.calls, isEmpty);
    // Hit the button corner, not its glyph: its whole rectangle is a target.
    await t.tapAt(t.getRect(control('increase')).topLeft + const Offset(2, 2));
    await t.pump();
    expect(fake.calls, [
      'fan.set_percentage {"entity_id":"fan.test","percentage":20}',
    ]);
    expect(find.text('20%'), findsOneWidget);
    await close(t);
  });

  testWidgets('more_info false consumes holds and unsupported taps', (t) async {
    final (fake, _, _) = await mount(
      t,
      moreInfo: false,
      attributes: {'supported_features': 17},
    );
    await t.longPress(find.text('Test fan'));
    await t.pumpAndSettle();
    await t.tap(find.text('Test fan'));
    await t.pumpAndSettle();
    expect(find.byType(FanSheet), findsNothing);
    expect(fake.calls, isEmpty);
  });

  testWidgets('horizontal swipes and cancelled touches belong to no service', (
    t,
  ) async {
    final (fake, _, _) = await mount(t);
    final gesture = await t.startGesture(t.getCenter(find.text('Test fan')));
    await t.pump(const Duration(milliseconds: 100));
    await gesture.cancel();
    await t.pump(const Duration(milliseconds: 600));
    await t.drag(find.text('Test fan'), const Offset(-420, 0));
    await t.pumpAndSettle();
    expect(find.text('Next page').hitTestable(), findsOneWidget);
    expect(find.byType(FanSheet), findsNothing);
    expect(fake.calls, isEmpty);
  });

  testWidgets(
    'vertical fill sends one snapped command on release, with stable echo',
    (t) async {
      final (fake, _, _) = await mount(
        t,
        attributes: {'supported_features': 17, 'percentage_step': 20},
      );
      await open(t);
      final box = t.getRect(control('level'));
      final gesture = await t.startGesture(
        Offset(box.center.dx, box.bottom - 2),
      );
      await gesture.moveTo(box.center);
      await t.pump();
      expect(fake.calls, isEmpty);
      await gesture.moveTo(Offset(box.center.dx, box.top + 2));
      await t.pump();
      expect(fake.calls, isEmpty);
      await gesture.up();
      await t.pump();
      expect(fake.calls, [
        'fan.set_percentage {"entity_id":"fan.test","percentage":100}',
      ]);
      expect(find.text('100%'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1600));
      expect(
        find.text('0%'),
        findsOneWidget,
        reason: 'unconfirmed echo returns to HA state',
      );
      await close(t);
    },
  );

  testWidgets(
    'fractional steps advance consecutively and reach zero; limits do not resend',
    (t) async {
      final (fake, states, _) = await mount(
        t,
        state: 'on',
        attributes: {
          'supported_features': 1,
          'percentage_step': 100 / 3,
          'percentage': 33,
        },
      );
      await open(t);
      for (final action in ['increase', 'decrease', 'decrease']) {
        await t.tap(control(action));
        await t.pump();
      }
      expect(fake.calls, [
        'fan.set_percentage {"entity_id":"fan.test","percentage":66}',
        'fan.set_percentage {"entity_id":"fan.test","percentage":33}',
        'fan.set_percentage {"entity_id":"fan.test","percentage":0}',
      ]);
      states.update(
        fanId,
        fan({'supported_features': 1, 'percentage': 100}, state: 'on'),
      );
      await t.pump(const Duration(milliseconds: 1600));
      await t.tap(control('increase'));
      await t.pump();
      expect(fake.calls.length, 3);
      await close(t);
    },
  );

  testWidgets(
    'preset-only sheet follows live state and closes after successful choice',
    (t) async {
      final (fake, states, _) = await mount(
        t,
        attributes: {
          'supported_features': 8,
          'preset_modes': ['auto', 'sleep'],
        },
      );
      await open(t);
      expect(control('level'), findsNothing);
      expect(find.text('Turn on'), findsNothing);
      states.update(
        fanId,
        fan({
          'supported_features': 8,
          'preset_modes': ['auto', 'sleep'],
          'preset_mode': 'auto',
        }, state: 'on'),
      );
      await t.pump();
      expect(
        sheet(t).actions.firstWhere((a) => a.label == 'auto').selected,
        isTrue,
      );
      expect(fake.calls, isEmpty);
      await t.tap(find.text('sleep'));
      await t.pumpAndSettle();
      expect(fake.calls, [
        'fan.set_preset_mode {"entity_id":"fan.test","preset_mode":"sleep"}',
      ]);
      expect(find.byType(FanSheet), findsNothing);
    },
  );

  testWidgets(
    'power-only: one contextual action; refusal stays open, success closes',
    (t) async {
      final (fake, _, _) = await mount(
        t,
        attributes: {'supported_features': 48},
      );
      fake.refuses = true;
      await open(t);
      expect(control('level'), findsNothing);
      expect(sheet(t).actions.length, 1);
      expect(find.text('Turn off'), findsNothing);
      await t.tap(find.text('Turn on'));
      await t.pump();
      expect(sheet(t).state, 'Off · Command failed');
      fake.refuses = false;
      await t.tap(find.text('Turn on'));
      await t.pumpAndSettle();
      expect(fake.calls.length, 2);
      expect(find.byType(FanSheet), findsNothing);
    },
  );

  testWidgets('rejected level rolls back echo and can be retried', (t) async {
    final (fake, _, _) = await mount(t);
    fake.refuses = true;
    await open(t);
    await t.tap(control('increase'));
    await t.pump();
    expect(sheet(t).state, contains('Command failed'));
    expect(find.text('0%'), findsOneWidget);
    expect(find.byType(FanSheet), findsOneWidget);
    await close(t);
  });

  testWidgets(
    'unavailable, missing and unknown entities stay inspectable without actions',
    (t) async {
      final (fake, states, _) = await mount(t);
      await open(t);
      for (final state in ['unavailable', 'unknown']) {
        states.update(fanId, fan({'supported_features': 49}, state: state));
        await t.pump();
        expect(sheet(t).enabled, isFalse);
        await t.tap(find.text('Turn on'));
        await t.pump();
        expect(fake.calls, isEmpty);
      }
      states.update(fanId, null);
      await t.pump();
      expect(sheet(t).actions, isEmpty);
      states.update(
        fanId,
        fan({'supported_features': 49, 'percentage': 60}, state: 'on'),
      );
      await t.pump();
      expect(find.text('60%'), findsOneWidget);
      await t.tap(find.text('Turn off'));
      await t.pumpAndSettle();
      expect(fake.calls, ['fan.turn_off {"entity_id":"fan.test"}']);
    },
  );

  testWidgets(
    'pending level prevents duplicate actions; disconnect disables controls',
    (t) async {
      final (fake, _, conn) = await mount(t);
      fake.delay = true;
      await open(t);
      await t.tap(control('increase'), warnIfMissed: false);
      await t.pump();
      await t.tap(control('increase'), warnIfMissed: false);
      await t.pump();
      expect(fake.calls.length, 1);
      expect(sheet(t).enabled, isFalse);
      fake.respond(fake.sent.last['id'] as int);
      await t.pump();
      expect(sheet(t).enabled, isTrue);
      await fake.close();
      await t.pump();
      expect(sheet(t).enabled, isFalse);
      unawaited(conn.dispose());
      await close(t);
    },
  );

  for (final loseCapability in [false, true]) {
    testWidgets(
      'cancelled level gesture and capability loss send no command ($loseCapability)',
      (t) async {
        final (fake, states, _) = await mount(t);
        await open(t);
        final box = t.getRect(control('level'));
        final gesture = await t.startGesture(
          Offset(box.center.dx, box.bottom - 2),
        );
        await gesture.moveTo(box.center);
        await t.pump();
        if (loseCapability) {
          states.update(fanId, fan({'supported_features': 48}));
          await t.pump();
          await gesture.up();
        } else {
          await gesture.cancel();
        }
        await t.pump();
        expect(fake.calls, isEmpty);
        if (!loseCapability) expect(find.text('0%'), findsOneWidget);
        await close(t);
      },
    );
  }

  testWidgets(
    'all presets stay reachable with 76-high targets; browse and Back send nothing',
    (t) async {
      final modes = List.generate(20, (i) => 'Automatic ventilation preset $i');
      final (fake, _, _) = await mount(
        t,
        attributes: {'supported_features': 57, 'preset_modes': modes},
      );
      await open(t);
      await t.tap(find.text('Presets'));
      await t.pumpAndSettle();
      expect(fake.calls, isEmpty);
      await t.scrollUntilVisible(
        find.text(modes.last),
        200,
        scrollable: find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.getSize(
          find.ancestor(
            of: find.text(modes.last),
            matching: find.byType(SheetButton),
          ),
        ),
        const Size(220, 76),
      );
      expect(t.takeException(), isNull);
      await t.tap(find.text('Back'));
      await t.pumpAndSettle();
      expect(fake.calls, isEmpty);
      await t.tap(find.text('Presets'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text(modes.last),
        200,
        scrollable: find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      await t.tap(find.text(modes.last));
      await t.pumpAndSettle();
      expect(
        fake.calls.single,
        'fan.set_preset_mode {"entity_id":"fan.test","preset_mode":"${modes.last}"}',
      );
    },
  );

  testWidgets(
    'fan and existing light sheet share actual 480px hitboxes and geometry',
    (t) async {
      final (fake, states, conn) = await mount(
        t,
        state: 'on',
        attributes: {'supported_features': 49, 'percentage': 40},
      );
      await open(t);
      Map<String, Rect> geometry() => {
        for (final name in ['close', 'level', 'increase', 'decrease'])
          name: t.getRect(control(name)),
      };
      final fanGeometry = geometry();
      expect(fanGeometry['close']!.size, const Size(56, 56));
      expect(fanGeometry['level']!.size, const Size(338, 288));
      expect(fanGeometry['increase']!.size, const Size(96, 137));
      expect(fanGeometry['decrease']!.size, const Size(96, 137));
      expect(
        t.getSize(
          find.ancestor(
            of: find.text('Turn off'),
            matching: find.byType(SheetButton),
          ),
        ),
        const Size(448, 76),
      );
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      await close(t);
      states.update(
        'light.test',
        const HaState(
          entityId: 'light.test',
          state: 'on',
          attributes: {
            'friendly_name': 'Test light',
            'brightness': 102,
            'supported_color_modes': ['brightness'],
          },
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: Ns.theme(),
          home: Scaffold(
            body: LightCard(
              config: {'entity': 'light.test', 'height': 260},
              env: PanelEnv(
                states: states,
                conn: conn,
                settings: Settings(url: 'http://fake', token: 'test'),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      await t.longPress(find.text('Test light'));
      await t.pumpAndSettle();
      expect(geometry(), fanGeometry);
      final actions = t
          .widgetList<SheetButton>(find.byType(SheetButton))
          .where((b) => ['Low', 'Mid', 'Full', 'Turn off'].contains(b.label));
      expect(actions.length, 4);
      for (final action in actions) {
        expect(t.getSize(find.byWidget(action)), const Size(106, 76));
      }
      expect(fake.calls, isEmpty);
      await close(t);
    },
  );
}
