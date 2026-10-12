import 'package:flutter/widgets.dart';

import '../config/dashboard.dart';
import '../util/navigation_controller.dart';
import '../extensions/camera_interaction.dart';
import '../config/settings.dart';
import '../ha/connection.dart';
import '../ha/states.dart';

/// What every card gets handed: the house, the socket, and where HA is.
class PanelEnv {
  const PanelEnv({
    required this.states,
    required this.conn,
    required this.settings,
    this.play,
    this.navigation,
    this.cameraInteraction,
    this.extensionCardBuilder,
  });
  final Widget? Function(CardConfig, PanelEnv)? extensionCardBuilder;
  final PanelNavigation? navigation;
  final CameraInteraction? cameraInteraction;
  final HaStates states;
  final HaConnection conn;
  final Settings settings;

  /// The panel's speaker, for a card that has a sound to make: takes what an
  /// announcement takes (`sound:armed`, a URL). Null off the panel.
  final void Function(String ref)? play;
}
