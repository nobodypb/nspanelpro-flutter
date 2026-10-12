import 'package:flutter/foundation.dart';

import '../config/settings.dart';
import '../extensions/camera_interaction.dart';
import 'doorbird/extension.dart';
import 'doorbird/profiles.dart';

/// The only composition point for private features; not part of upstream PRs.
class LocalExtensions {
  LocalExtensions({
    required VoidCallback Function() holdDisplay,
    required VoidCallback Function() holdNavigation,
    required Future<void> Function() beforeMedia,
    Future<bool> Function(String, String, Map<String, dynamic>)? callService,
  }) : _doorbird = DoorBirdExtension(
         holdDisplay: holdDisplay,
         holdNavigation: holdNavigation,
         beforeMedia: beforeMedia,
         callService: callService,
       );
  static Future<void> provision(Map<String, dynamic> input) =>
      DoorBirdProfiles.provision(input);
  static Future<void> clearSettings() =>
      Settings.clear(clearLocalSettings: DoorBirdProfiles.clear);
  final DoorBirdExtension _doorbird;
  CameraInteraction get camera => _doorbird;
  bool get ownsAudio => _doorbird.suspendsStillImages;
  void dispose() => _doorbird.dispose();
}
