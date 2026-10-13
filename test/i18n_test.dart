import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/config/screensaver.dart';
import 'package:nspanel_app/config/settings.dart';
import 'package:nspanel_app/l10n/app_localizations.dart';
import 'package:nspanel_app/ui/screensaver.dart';
import 'package:nspanel_app/ui/setup_screen.dart';
import 'package:nspanel_app/ui/sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('language selection updates setup and persists after saving', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(480, 480);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    String language = '';
    Settings? saved;
    await t.pumpWidget(StatefulBuilder(builder: (context, update) => MaterialApp(
      locale: Locale(language.isEmpty ? 'en' : language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SetupScreen(
        initial: Settings(url: 'http://example.invalid', token: 'test'),
        onLanguage: (value) => update(() => language = value),
        onSaved: (value) => saved = value,
      ),
    )));
    expect(find.text('Connect to Home Assistant'), findsOneWidget);
    await t.tap(find.text('System'));
    await t.pumpAndSettle();
    await t.tap(find.text('Deutsch').last);
    await t.pumpAndSettle();
    expect(language, 'de');
    expect(find.text('Mit Home Assistant verbinden'), findsOneWidget);
    final connect = find.text('Verbinden');
    await t.scrollUntilVisible(connect, 250, scrollable: find.byType(Scrollable).first);
    await t.tap(connect);
    await t.pumpAndSettle();
    expect(saved?.language, 'de');
    expect((await Settings.load())?.language, 'de');
    expect(t.takeException(), isNull);
  });

  testWidgets('German controls and date fit the 480-pixel panel', (t) async {
    t.view.physicalSize = const Size(480, 480);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: ControlSheet(
        title: 'Test', state: 'An', value: .5, accent: Colors.amber,
        fromTop: false, step: 5, actions: [],
      )),
    ));
    await t.pump();
    expect(t.widget<SheetButton>(find.byKey(const ValueKey('sheet-close'))).label, 'Schließen');
    expect(t.widget<SheetButton>(find.byKey(const ValueKey('sheet-increase'))).label, 'Erhöhen');
    expect(t.getSize(find.byKey(const ValueKey('sheet-close'))).width, greaterThanOrEqualTo(56));
    expect(t.takeException(), isNull);

    await t.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Screensaver(config: ScreensaverConfig.fromMap({'clock_position': 'center'}), onWake: () {}),
    ));
    await t.pump();
    expect(find.byType(Text), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });
}
