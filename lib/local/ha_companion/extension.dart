import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ha_companion_handoff/ha_companion_handoff.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../config/dashboard.dart';
import '../../ui/page_scope.dart';
import '../../ui/sheet.dart';
import '../../ui/theme.dart';
import '../../util/display_controller.dart';
import '../../util/icons.dart';
import '../../util/navigation_controller.dart';
import 'settings.dart';

class CompanionExtension {
  CompanionExtension(
    this.display,
    this.navigation, {
    HandoffTransport? transport,
    Future<bool> Function()? enabled,
  }) {
    controller = HandoffController(
      transport ?? NativeHandoffTransport(),
      acquire: () {
        _lease ??= display.beginExternalSession();
        _releaseNavigation ??= navigation.hold();
      },
      prepareReturn: (dark) async {
        await _lease?.prepareReturn(dark: dark);
        _releaseNavigation?.call();
        _releaseNavigation = null;
        navigation.closeDialogs();
        navigation.navigate(navigation.start);
      },
      release: () {
        _releaseNavigation?.call();
        _releaseNavigation = null;
        _lease?.release();
        _lease = null;
      },
    );
    unawaited(_configure(enabled ?? CompanionSettings.enabled));
  }
  final DisplayController display;
  final PanelNavigation navigation;
  late final HandoffController controller;
  ExternalDisplayLease? _lease;
  VoidCallback? _releaseNavigation;
  bool _disposed = false;
  Future<void> _configure(Future<bool> Function() enabled) async {
    if (await enabled() && !_disposed) await controller.check();
  }

  Widget? buildCard(CardConfig config) =>
      cardType(config) == 'nspanel-ha-app-card'
      ? CompanionCard(config: config, controller: controller)
      : null;
  void dispose() {
    _disposed = true;
    controller.dispose();
  }
}

class CompanionCard extends StatelessWidget {
  const CompanionCard({
    super.key,
    required this.config,
    required this.controller,
  });
  final CardConfig config;
  final HandoffController controller;
  @override
  Widget build(BuildContext context) {
    final scope = PageScope.maybeOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller,
        if (scope != null) scope.changes,
      ]),
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: config.numOr('height', 76).clamp(76, 900),
            width: double.infinity,
            child: SheetButton(
              label: config.titleOr('Home Assistant'),
              onTap:
                  controller.supported &&
                      !controller.active &&
                      (scope?.active ?? true)
                  ? () => unawaited(controller.begin())
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    mdi(config.str('icon'), MdiIcons.homeAssistant),
                    color: Ns.text,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      config.titleOr('Home Assistant'),
                      style: const TextStyle(
                        color: Ns.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (controller.error != null || !controller.supported)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                controller.error ??
                    'HA-Wechsel auf diesem Gerät nicht verfügbar',
                style: TextStyle(
                  color: controller.error == null ? Ns.muted : Ns.danger,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
