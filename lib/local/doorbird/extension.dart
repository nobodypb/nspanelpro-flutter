import 'dart:async';

import 'package:doorbird_intercom/doorbird_intercom.dart';
import 'package:flutter/widgets.dart';

import '../../extensions/camera_interaction.dart';
import 'camera_view.dart';
import 'profiles.dart';

/// Translate the stable host capabilities to the private media package.
class DoorBirdExtension extends ChangeNotifier implements CameraInteraction {
  DoorBirdExtension({
    required this.holdDisplay,
    required this.holdNavigation,
    required Future<void> Function() beforeMedia,
    IntercomTransport? transport,
    this.loadProfile = DoorBirdProfiles.read,
    this.callService,
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
  final Future<bool> Function(String, String, Map<String, dynamic>)?
  callService;
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
  Object? _owner;
  int _request = 0;
  bool _loading = false;

  @override
  Widget? build(
    BuildContext context,
    Map<String, dynamic> config,
    Widget picture,
  ) {
    final option = config['intercom'];
    final name = option is Map ? option['profile'] : null;
    if (name is! String || name.isEmpty) return null;
    final opener = option is Map ? option['door_opener'] : null;
    final entity = opener is Map ? opener['entity'] : null;
    return IntercomCameraView(
      key: ValueKey('${config['entity']}:$name'),
      controller: controller,
      autoLive: option is Map && option['auto_live'] == true,
      openDoor:
          callService != null &&
              entity is String &&
              RegExp(r'^button\.[a-z0-9_]+$').hasMatch(entity)
          ? () => callService!('button', 'press', {'entity_id': entity})
          : null,
      title: (config['title'] ?? config['name'] ?? 'DoorBird').toString(),
      contain: config['fit'] == 'contain',
      picture: picture,
      ownsSession: (owner) => identical(_owner, owner),
      onStart: (owner) => _open(owner, name),
      onStop: _stop,
    );
  }

  Future<void> _open(Object owner, String name) async {
    if (_disposed || _loading || controller.inUse) return;
    _owner = owner;
    _loading = true;
    final request = ++_request;
    try {
      final profile = await loadProfile(name);
      if (!_disposed && request == _request && identical(owner, _owner)) {
        await controller.open(profile);
      }
    } finally {
      if (request == _request) _loading = false;
    }
  }

  void _stop(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _request++;
    _loading = false;
    // Disposal/page changes can happen during a build. Close before another
    // session may open, but deliver controller notifications outside that build.
    scheduleMicrotask(() {
      if (!_disposed && _owner == null) unawaited(controller.close());
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    controller.removeListener(notifyListeners);
    controller.dispose();
    super.dispose();
  }
}
