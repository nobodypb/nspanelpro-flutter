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

  testWidgets(
    'hold, release and close send no command on standalone upstream',
    (tester) async {
      final (fake, _, _) = await mount(tester);
      await open(tester);
      expect(fake.calls, isEmpty);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);
      await tester.tap(find.text('Test fan'));
      await tester.pump();
      expect(fake.calls, ['fan.turn_on {"entity_id":"fan.test"}']);
    },
  );

  testWidgets('hood tap opens speed without unsupported turn_on', (
    tester,
  ) async {
    final (fake, _, _) = await mount(
      tester,
      attributes: {'supported_features': 17, 'percentage_step': 20},
    );
    await tester.tap(find.text('Test fan'));
    await tester.pumpAndSettle();
    expect(find.byType(FanSheet), findsOneWidget);
    expect(find.text('Turn on'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(fake.calls, isEmpty);
    await tester.tap(find.byTooltip('Increase speed'));
    await tester.pump();
    expect(fake.calls, [
      'fan.set_percentage {"entity_id":"fan.test","percentage":20}',
    ]);
  });

  testWidgets('more_info false consumes holds and unsupported taps', (
    tester,
  ) async {
    final (fake, _, _) = await mount(
      tester,
      moreInfo: false,
      attributes: {'supported_features': 17},
    );
    await tester.longPress(find.text('Test fan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test fan'));
    await tester.pumpAndSettle();
    expect(find.byType(FanSheet), findsNothing);
    expect(fake.calls, isEmpty);
  });

  testWidgets('horizontal swipe and cancelled touch never send commands', (
    tester,
  ) async {
    final (fake, _, _) = await mount(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Test fan')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.drag(find.text('Test fan'), const Offset(-420, 0));
    await tester.pumpAndSettle();
    expect(find.text('Next page').hitTestable(), findsOneWidget);
    expect(find.byType(FanSheet), findsNothing);
    expect(fake.calls, isEmpty);
  });

  testWidgets('speed drag sends exactly one snapped command on release', (
    tester,
  ) async {
    final (fake, _, _) = await mount(
      tester,
      attributes: {'supported_features': 17, 'percentage_step': 20},
    );
    await open(tester);
    final box = tester.getRect(find.byType(Slider));
    final gesture = await tester.startGesture(
      Offset(box.left + 24, box.center.dy),
    );
    await gesture.moveTo(Offset(box.center.dx, box.center.dy));
    await tester.pump();
    expect(fake.calls, isEmpty);
    await gesture.moveTo(Offset(box.right - 24, box.center.dy));
    await tester.pump();
    expect(fake.calls, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(fake.calls, [
      'fan.set_percentage {"entity_id":"fan.test","percentage":100}',
    ]);
  });

  testWidgets('fractional speed steps, boundaries and zero use speed service', (
    tester,
  ) async {
    final (fake, states, _) = await mount(
      tester,
      state: 'on',
      attributes: {
        'supported_features': 1,
        'percentage_step': 100 / 3,
        'percentage': 33,
      },
    );
    await open(tester);
    await tester.tap(find.byTooltip('Increase speed'));
    await tester.pump();
    expect(
      fake.calls.last,
      'fan.set_percentage {"entity_id":"fan.test","percentage":66}',
    );
    await tester.tap(find.byTooltip('Decrease speed'));
    await tester.pump();
    expect(
      fake.calls.last,
      'fan.set_percentage {"entity_id":"fan.test","percentage":0}',
    );
    states.update(
      fanId,
      fan({'supported_features': 1, 'percentage': 100}, state: 'on'),
    );
    await tester.pump();
    final before = fake.calls.length;
    await tester.tap(find.byTooltip('Increase speed'));
    await tester.pump();
    expect(fake.calls.length, before);
  });

  testWidgets(
    'preset-only fan follows external state and sends domain-correct action',
    (tester) async {
      final (fake, states, _) = await mount(
        tester,
        attributes: {
          'supported_features': 8,
          'preset_modes': ['auto', 'sleep'],
        },
      );
      await open(tester);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Turn on'), findsNothing);
      await tester.tap(find.text('sleep'));
      await tester.pump();
      expect(fake.calls, [
        'fan.set_preset_mode {"entity_id":"fan.test","preset_mode":"sleep"}',
      ]);
      states.update(
        fanId,
        fan({
          'supported_features': 8,
          'preset_modes': ['auto', 'sleep'],
          'preset_mode': 'auto',
        }, state: 'on'),
      );
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'auto'))
            .selected,
        isTrue,
      );
    },
  );

  testWidgets(
    'power-only fan exposes no speed; failure remains visible and retry works',
    (tester) async {
      final (fake, _, _) = await mount(
        tester,
        attributes: {'supported_features': 48},
      );
      fake.refuses = true;
      await open(tester);
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.text('Turn on'));
      await tester.pump();
      expect(find.text('Off · Command failed'), findsOneWidget);
      expect(find.byType(FanSheet), findsOneWidget);
      fake.refuses = false;
      await tester.tap(find.text('Turn on'));
      await tester.pump();
      expect(fake.calls.length, 2);
      expect(find.textContaining('Command failed'), findsNothing);
    },
  );

  testWidgets(
    'unavailable, missing and unknown states disable actions and recover',
    (tester) async {
      final (fake, states, _) = await mount(tester);
      await open(tester);
      for (final state in ['unavailable', 'unknown']) {
        states.update(fanId, fan({'supported_features': 49}, state: state));
        await tester.pump();
        expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
        await tester.tap(find.text('Turn on'));
        await tester.pump();
        expect(fake.calls, isEmpty);
      }
      states.update(fanId, null);
      await tester.pump();
      expect(find.text('No supported controls'), findsOneWidget);
      states.update(
        fanId,
        fan({'supported_features': 49, 'percentage': 60}, state: 'on'),
      );
      await tester.pump();
      expect(find.text('60%'), findsOneWidget);
      await tester.tap(find.text('Turn off'));
      await tester.pump();
      expect(fake.calls, ['fan.turn_off {"entity_id":"fan.test"}']);
    },
  );

  testWidgets(
    'pending command disables duplicate actions; disconnect recovers safely',
    (tester) async {
      final (fake, _, conn) = await mount(tester);
      fake.delay = true;
      await open(tester);
      await tester.tap(find.text('Turn on'));
      await tester.pump();
      await tester.tap(find.text('Turn on'));
      await tester.pump();
      expect(fake.calls.length, 1);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      fake.respond(fake.sent.last['id'] as int);
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);
      await fake.close();
      await tester.pump();
      expect(conn.isOnline, isFalse);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      unawaited(conn.dispose());
      await tester.pump();
    },
  );

  testWidgets(
    'cancelled slider gesture sends nothing and restores live value',
    (tester) async {
      final (fake, _, _) = await mount(tester);
      await open(tester);
      final box = tester.getRect(find.byType(Slider));
      final gesture = await tester.startGesture(
        Offset(box.left + 24, box.center.dy),
      );
      await gesture.moveTo(box.center);
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      expect(fake.calls, isEmpty);
      expect(find.text('0%'), findsOneWidget);
    },
  );

  testWidgets('losing speed capability during drag prevents dispatch', (
    tester,
  ) async {
    final (fake, states, _) = await mount(tester);
    await open(tester);
    final box = tester.getRect(find.byType(Slider));
    final gesture = await tester.startGesture(
      Offset(box.left + 24, box.center.dy),
    );
    await gesture.moveTo(box.center);
    await tester.pump();
    states.update(fanId, fan({'supported_features': 48}));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(fake.calls, isEmpty);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('long names and many presets fit 480 square without overflow', (
    tester,
  ) async {
    final (fake, _, _) = await mount(
      tester,
      attributes: {
        'supported_features': 57,
        'preset_modes': List.generate(
          20,
          (i) => 'Automatic ventilation preset $i',
        ),
      },
    );
    await open(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(fake.calls, isEmpty);
  });
}
