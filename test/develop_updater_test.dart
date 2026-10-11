import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/update/updater.dart';

void main() {
  test(
    'local builds cannot fetch or install even an explicitly supplied release',
    () async {
      final dir = await Directory.systemTemp.createTemp('develop-updater');
      addTearDown(() => dir.delete(recursive: true));
      final updater = Updater(
        installed: '0.6.0-develop',
        dir: dir,
        enabled: false,
        fetch: (_) async => throw StateError('Unexpected network request'),
        download: (_, _, _) async =>
            throw StateError('Unexpected APK download'),
      );
      const release = UpdateInfo(
        version: '99.0.0',
        url: 'https://example.invalid/release',
        notes: '',
        apkUrl: 'https://example.invalid/update.apk',
        size: 1,
      );
      updater.latest.value = release;
      expect(updater.updateAvailable, isFalse);
      expect(await updater.install(release), isFalse);
      expect(await updater.install(), isFalse);
      expect(await updater.check(), isNull);
      expect(updater.latest.value, isNull);
      expect(updater.status.value, contains('local develop'));
      expect(await dir.list().toList(), isEmpty);
    },
  );
}
