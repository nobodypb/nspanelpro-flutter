import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../cards/env.dart';
import '../config/dashboard.dart';
import '../util/display_controller.dart';
import 'ha_companion/extension.dart';
import 'ha_companion/settings.dart';

import '../config/settings.dart';
import '../extensions/camera_interaction.dart';
import 'doorbird/extension.dart';
import 'doorbird/profiles.dart';
import '../util/navigation_controller.dart';

/// The only composition point for private features; not part of upstream PRs.
class LocalExtensions {
  LocalExtensions({
    required VoidCallback Function() holdDisplay,
    required VoidCallback Function() holdNavigation,
    required Future<void> Function() beforeMedia,
    required PanelNavigation navigation,
    DisplayController? display,
    required ValueListenable<int> shownPage,
    required bool Function() foreground,
    required bool Function(int) canShow,
    Future<bool> Function(String, String, Map<String, dynamic>)? callService,
  }) : _doorbird = DoorBirdExtension(
         holdDisplay: holdDisplay,
         holdRingDisplay: display == null
             ? holdDisplay
             : () => display.hold(reason: 'ring'),
         holdNavigation: holdNavigation,
         beforeMedia: beforeMedia,
         callService: callService,
         navigation: navigation,
         shownPage: shownPage,
         foreground: foreground,
         canShow: canShow,
       ),
       _companion = display == null
           ? null
           : CompanionExtension(display, navigation);
  final CompanionExtension? _companion;
  Widget? buildCard(CardConfig config, PanelEnv env) =>
      _companion?.buildCard(config);
  static Future<void> provision(Map<String, dynamic> input) => Future.wait([
    DoorBirdProfiles.provision(input),
    CompanionSettings.provision(input),
  ]).then((_) {});
  static Future<void> clearSettings() => Settings.clear(
    clearLocalSettings: () async {
      await DoorBirdProfiles.clear();
      await CompanionSettings.clear();
    },
  );
  final DoorBirdExtension _doorbird;
  void command(Map<String, dynamic> value) => _doorbird.rings?.command(value);
  void visibility(bool foreground, bool saving) =>
      _doorbird.visibility(foreground, saving);
  CameraInteraction get camera => _doorbird;
  bool get ownsAudio => _doorbird.suspendsStillImages;
  void dispose() {
    _companion?.dispose();
    _doorbird.dispose();
  }
}
