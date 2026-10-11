import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nspanel_app/config/settings.dart';
import 'package:nspanel_app/ui/setup_screen.dart';
import 'package:nspanel_app/local/extensions.dart';
import 'package:nspanel_app/local/doorbird/profiles.dart';

void main() {
  testWidgets(
    'editing HA setup preserves private profiles and clear removes them',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final profiles = {
        'entrance': {
          'host': 'example.invalid',
          'username': 'test',
          'password': 'test-only',
          'certificate_sha256': '0' * 64,
        },
      };
      final original = Settings(url: 'http://ha.invalid', token: 'fake');
      await original.save();
      await LocalExtensions.provision({'intercom_profiles': profiles});
      final loaded = await Settings.load();
      expect(await DoorBirdProfiles.read('entrance'), profiles['entrance']);
      Settings? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: SetupScreen(initial: loaded!, onSaved: (s) => saved = s),
        ),
      );
      final connect = find.text('Connect');
      await tester.scrollUntilVisible(
        connect,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(connect);
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(await DoorBirdProfiles.read('entrance'), profiles['entrance']);
      await LocalExtensions.clearSettings();
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'intercom_profiles',
        ),
        false,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
