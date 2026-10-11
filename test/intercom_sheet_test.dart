import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/cards/env.dart';
import 'package:nspanel_app/config/settings.dart';
import 'package:nspanel_app/ha/connection.dart';
import 'package:nspanel_app/ha/states.dart';
import 'package:nspanel_app/intercom/intercom.dart';
import 'package:nspanel_app/intercom/intercom_sheet.dart';
import 'package:nspanel_app/ui/sheet.dart';

import 'intercom_test.dart' show FakeIntercom;
import 'connection_test.dart' show FakeHa;

void main() {
  testWidgets('probe preserves large controls and explicit microphone intent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FakeIntercom();
    final controller = IntercomController(transport);
    final states = HaStates();
    final conn = HaConnection(
      transportFactory: () async => FakeHa({}),
      token: 'test',
      states: states,
    );
    final env = PanelEnv(
      states: states,
      conn: conn,
      settings: Settings(url: 'http://fake', token: 'test'),
      intercom: controller,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showIntercomProbe(context, env, 'probe', 'DoorBird'),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    transport.emit('preview');
    await tester.pump();
    expect(find.text('Live · Hören · Mikrofon aus'), findsOneWidget);
    expect(transport.calls, isNot(contains('mic:true')));
    final buttons = find.byType(SheetButton);
    for (final e in buttons.evaluate()) {
      final size = tester.getSize(find.byWidget(e.widget));
      expect(size.width, greaterThanOrEqualTo(56));
      expect(size.height, greaterThanOrEqualTo(56));
    }
    final plus = find.widgetWithIcon(SheetButton, Icons.add);
    expect(tester.getSize(plus), const Size(96, 137));
    await tester.tap(find.text('Sprechen'));
    await tester.pumpAndSettle();
    expect(find.text('Gespräch · Mikrofon an'), findsOneWidget);
    await tester.tap(find.text('Stumm'));
    await tester.pumpAndSettle();
    expect(find.text('Gespräch · Mikrofon aus'), findsOneWidget);
    await tester.tap(find.text('Auflegen'));
    await tester.pumpAndSettle();
    expect(controller.state, IntercomState.idle);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    conn.dispose();
    await transport.stream.close();
  });
}
