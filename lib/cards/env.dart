import 'package:flutter/widgets.dart';

import '../config/dashboard.dart';
import '../util/navigation_controller.dart';
import '../extensions/camera_interaction.dart';
import '../config/settings.dart';
import '../ui/page_scope.dart';
import '../util/usage_candidates.dart';
import '../util/usage_history.dart';
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
    this.usage,
    this.usageCandidates,
  });
  final Widget? Function(CardConfig, PanelEnv)? extensionCardBuilder;
  final PanelNavigation? navigation;
  final CameraInteraction? cameraInteraction;
  final HaStates states;
  final HaConnection conn;
  final Settings settings;
  final UsageHistory? usage;
  final List<UsageCandidate> Function()? usageCandidates;

  UsageEvent? recordUsage(
    BuildContext context,
    String entity,
    String card,
    String gesture, {
    String result = 'pending',
  }) {
    final page = PageScope.maybeOf(context)?.index ?? -1;
    return usage?.record(entity, card, page, gesture, result: result);
  }

  Future<bool> trackCall(
    BuildContext context,
    String entity,
    String card,
    String gesture,
    Future<bool> Function() action,
  ) async {
    final event = recordUsage(context, entity, card, gesture);
    try {
      final ok = await action();
      usage?.complete(event, ok);
      return ok;
    } catch (_) {
      usage?.complete(event, false);
      rethrow;
    }
  }

  /// The panel's speaker, for a card that has a sound to make: takes what an
  /// announcement takes (`sound:armed`, a URL). Null off the panel.
  final void Function(String ref)? play;
}
