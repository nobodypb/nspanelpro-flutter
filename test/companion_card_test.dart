import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ha_companion_handoff/ha_companion_handoff.dart';
import 'package:nspanel_app/local/ha_companion/extension.dart';
import 'package:nspanel_app/local/ha_companion/settings.dart';
import 'package:nspanel_app/ui/page_scope.dart';
import 'package:nspanel_app/ui/sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Transport implements HandoffTransport {
  final bus = StreamController<Map<String, dynamic>>.broadcast();
  int starts = 0;
  @override
  Stream<Map<String, dynamic>> get events => bus.stream;
  @override
  Future<bool> available() async => true;
  @override
  Future<void> begin() async {
    starts++;
  }

  @override
  Future<void> prepared(String id) async {}
  @override
  Future<void> finish(String id) async {}
}

void main() {
  testWidgets('visible card has 76px target, warmup cannot launch', (t) async {
    await t.binding.setSurfaceSize(const Size(480, 480));
    final f = Transport();
    final c = HandoffController(
      f,
      acquire: () {},
      release: () {},
      prepareReturn: (_) async {},
    );
    await c.check();
    final shown = ValueNotifier(7), awake = ValueNotifier(true);
    Widget card(int index) => MaterialApp(
      home: Scaffold(
        body: PageScope(
          index: index,
          shown: shown,
          awake: awake,
          child: CompanionCard(
            config: const {'type': 'custom:nspanel-ha-app-card'},
            controller: c,
          ),
        ),
      ),
    );
    await t.pumpWidget(card(-1));
    await t.tap(find.byType(SheetButton));
    expect(f.starts, 0);
    await t.pumpWidget(card(7));
    expect(t.getSize(find.byType(SheetButton)), const Size(480, 76));
    await t.tap(find.byType(SheetButton));
    await t.pump();
    expect(f.starts, 1);
    await t.tap(find.byType(SheetButton));
    expect(f.starts, 1);
    await t.pumpWidget(const SizedBox());
    c.dispose();
    await f.bus.close();
    shown.dispose();
    awake.dispose();
    await t.binding.setSurfaceSize(null);
  });
  test('local provisioning is opt-in and absent values preserve it', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await CompanionSettings.enabled(), false);
    await CompanionSettings.provision({CompanionSettings.key: true});
    await CompanionSettings.provision({'url': 'unrelated'});
    expect(await CompanionSettings.enabled(), true);
    await CompanionSettings.clear();
    expect(await CompanionSettings.enabled(), false);
  });
}
