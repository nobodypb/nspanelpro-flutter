import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/local/doorbird/ring_controller.dart';
import 'package:nspanel_app/util/navigation_controller.dart';

void main() {
  late PanelNavigation navigation;
  late DoorBirdRingController rings;
  late ValueNotifier<int> shown;
  late DateTime now;
  var holds = 0, sounds = 0;
  var conversation = false, foreground = true;
  Map<String, dynamic> event([DateTime? time]) => {
    'type': 'doorbird.ring',
    'page': 0,
    'event_id': (time ?? now).toUtc().toIso8601String(),
  };
  setUp(() {
    now = DateTime.utc(2026, 10, 12);
    holds = 0;
    sounds = 0;
    conversation = false;
    foreground = true;
    navigation = PanelNavigation(now: () => now.millisecondsSinceEpoch);
    navigation.configure(
      count: 4,
      start: 3,
      after: 15,
      overrides: {0: 60},
      structure: 'test',
    );
    shown = ValueNotifier(3);
    rings = DoorBirdRingController(
      navigation: navigation,
      shownPage: shown,
      holdDisplay: () {
        holds++;
        return () => holds--;
      },
      play: () async {
        sounds++;
      },
      stopTone: () async {},
      foreground: () => foreground,
      canShow: (page) => page == 0,
      inConversation: () => conversation,
      beforeRing: () {},
      now: () => now,
    );
  });
  tearDown(() {
    rings.dispose();
    navigation.dispose();
    shown.dispose();
  });

  test(
    'ring wakes, returns exactly once after 60 seconds, releases display',
    () {
      rings.command(event());
      shown.value = 0;
      expect([navigation.current, holds, sounds], [0, 1, 1]);
      now = now.add(const Duration(seconds: 59));
      navigation.check();
      expect(navigation.current, 0);
      now = now.add(const Duration(seconds: 1));
      navigation.check();
      expect([navigation.current, holds], [3, 0]);
      navigation.check();
      expect(holds, 0);
    },
  );
  test('duplicate and stale rings do nothing; real repeat and touch renew deadline', () {
    final first = event();
    rings.command(first);
    shown.value = 0;
    now = now.add(const Duration(seconds: 5));
    rings.command(first);
    expect(sounds, 1);
    rings.command(event(now.subtract(const Duration(seconds: 11))));
    expect(sounds, 1);
    rings.command(event());
    expect([sounds, holds], [2, 1]);
    now = now.add(const Duration(seconds: 59));
    navigation.check();
    expect(navigation.current, 0);
    navigation.activity();
    now = now.add(const Duration(seconds: 59));
    navigation.check();
    expect(navigation.current, 0);
    now = now.add(const Duration(seconds: 1));
    navigation.check();
    expect(holds, 0);
  });
  test(
    'conversation including mute prevents return and repeat does not navigate',
    () {
      rings.command(event());
      shown.value = 0;
      conversation = true;
      final release = navigation.hold();
      final revision = navigation.revision;
      now = now.add(const Duration(seconds: 61));
      navigation.check();
      rings.command(event());
      expect(
        [navigation.current, navigation.revision, sounds, holds],
        [0, revision, 2, 1],
      );
      conversation = false;
      release();
      now = now.add(const Duration(seconds: 60));
      navigation.check();
      expect([navigation.current, holds], [3, 0]);
    },
  );
  test('manual navigation, background and disposal release once', () {
    rings.command(event());
    shown.value = 0;
    navigation.navigate(2);
    expect(holds, 0);
    now = now.add(const Duration(seconds: 1));
    rings.command(event());
    expect(holds, 1);
    rings.cancel();
    expect(holds, 0);
    foreground = false;
    now = now.add(const Duration(seconds: 1));
    rings.command(event());
    expect(holds, 0);
  });
  test('invalid page and future events cannot wake or play', () {
    rings.command({...event(), 'page': 3});
    rings.command({...event(), 'page': 99});
    rings.command(event(now.add(const Duration(seconds: 5))));
    rings.command({...event(), 'event_id': 'invalid'});
    expect([holds, sounds], [0, 0]);
  });
}
