import 'dart:async';

import 'package:doorbird_intercom/doorbird_intercom.dart';
import 'package:flutter/widgets.dart';

import '../../extensions/camera_interaction.dart';
import 'intercom_sheet.dart';
import 'profiles.dart';

/// Translate the stable host capabilities to the private media package.
class DoorBirdExtension extends ChangeNotifier implements CameraInteraction {
  DoorBirdExtension({
    required this.holdDisplay,
    required this.holdNavigation,
    required Future<void> Function() beforeMedia,
    IntercomTransport? transport,
    this.loadProfile = DoorBirdProfiles.read,
  }) {
    controller = IntercomController(
      transport ?? NativeIntercomTransport(),
      onBusy: _busy,
      beforeOpen: beforeMedia,
    )..addListener(notifyListeners);
  }
  final VoidCallback Function() holdDisplay, holdNavigation;
  late final IntercomController controller;
  final Future<Map<String, dynamic>> Function(String) loadProfile;
  bool _disposed = false;
  VoidCallback? _releaseDisplay, _releaseNavigation;
  void _busy(bool busy) {
    if (busy) {
      _releaseDisplay ??= holdDisplay();
      _releaseNavigation ??= holdNavigation();
    } else {
      _releaseDisplay?.call();
      _releaseDisplay = null;
      _releaseNavigation?.call();
      _releaseNavigation = null;
    }
  }

  @override
  bool get suspendsStillImages => controller.inUse;
  @override
  VoidCallback? action(BuildContext context, Map<String, dynamic> config) {
    final option = config['intercom'];
    final name = option is Map ? option['profile'] : null;
    if (name is! String || name.isEmpty) return null;
    return () => unawaited(
      _open(context, name, config['title']?.toString() ?? 'DoorBird'),
    );
  }

  Future<void> _open(BuildContext context, String name, String title) async {
    final profile = await loadProfile(name);
    if (!_disposed && context.mounted) {
      await showIntercomProbe(context, controller, profile, title);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(notifyListeners);
    controller.dispose();
    super.dispose();
  }
}
