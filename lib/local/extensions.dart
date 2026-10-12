import 'package:flutter/foundation.dart';

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
    required ValueListenable<int> shownPage,
    required bool Function() foreground,
    required bool Function(int) canShow,
    Future<bool> Function(String, String, Map<String, dynamic>)? callService,
  }) : _doorbird = DoorBirdExtension(
         holdDisplay: holdDisplay,
         holdNavigation: holdNavigation,
         beforeMedia: beforeMedia,
         callService: callService,
         navigation: navigation,
         shownPage: shownPage,
         foreground: foreground,
         canShow: canShow,
       );
  static Future<void> provision(Map<String, dynamic> input) =>
      DoorBirdProfiles.provision(input);
  static Future<void> clearSettings() =>
      Settings.clear(clearLocalSettings: DoorBirdProfiles.clear);
  final DoorBirdExtension _doorbird;
  void command(Map<String, dynamic> value) => _doorbird.rings?.command(value);
  void visibility(bool foreground, bool saving) =>
      _doorbird.visibility(foreground, saving);
  CameraInteraction get camera => _doorbird;
  bool get ownsAudio => _doorbird.suspendsStillImages;
  void dispose() => _doorbird.dispose();
}
