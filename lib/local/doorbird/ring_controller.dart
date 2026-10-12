import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../util/navigation_controller.dart';

/// Ring lifetime uses the dashboard's existing inactivity deadline, never a
/// second return timer. Audio and private media remain in the extension.
class DoorBirdRingController {
  DoorBirdRingController({
    required this.navigation,
    required this.shownPage,
    required this.holdDisplay,
    required this.play,
    required this.stopTone,
    required this.foreground,
    required this.canShow,
    required this.inConversation,
    required this.beforeRing,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    navigation.addListener(_navigationChanged);
    shownPage.addListener(_shownChanged);
  }
  final PanelNavigation navigation;
  final ValueListenable<int> shownPage;
  final VoidCallback Function() holdDisplay;
  final Future<void> Function() play;
  final Future<void> Function() stopTone;
  final bool Function() foreground;
  final bool Function(int) canShow;
  final bool Function() inConversation;
  final VoidCallback beforeRing;
  final DateTime Function() _now;
  final revision = ValueNotifier(0);
  final _seen = <String, DateTime>{};
  int? _page;
  bool _arrived = false, _disposed = false;
  VoidCallback? _release;
  bool get active => _page != null;

  void command(Map<String, dynamic> command) {
    if (_disposed || command['type'] != 'doorbird.ring' || !foreground()) {
      return;
    }
    final id = command['event_id'];
    final page = command['page'];
    if (id is! String ||
        page is! int ||
        !navigation.valid(page) ||
        !canShow(page)) {
      return;
    }
    final time = DateTime.tryParse(id);
    final now = _now();
    if (time == null ||
        now.difference(time).inMilliseconds < -2000 ||
        now.difference(time).inSeconds >= 10) {
      return;
    }
    _seen.removeWhere((_, value) => now.difference(value).inSeconds >= 12);
    if (_seen.containsKey(id)) return;
    _seen[id] = time;
    debugPrint(
      'local ring: accepted page=$page conversation=${inConversation()}',
    );
    // An accepted/muted call keeps its navigation hold. Notify without moving it.
    if (inConversation()) {
      unawaited(play());
      return;
    }
    beforeRing();
    _release ??= holdDisplay();
    _page = page;
    _arrived = shownPage.value == page;
    // Start the chime before a visible page can auto-open its media session.
    unawaited(play());
    if (!navigation.navigate(page)) {
      cancel();
      return;
    }
    revision.value++;
  }

  void _navigationChanged() {
    if (active && navigation.target != null && navigation.target != _page) {
      cancel();
    }
  }

  void _shownChanged() {
    if (!active) return;
    if (shownPage.value == _page) {
      _arrived = true;
    } else if (_arrived) {
      cancel();
    }
  }

  void cancel() {
    _page = null;
    _arrived = false;
    _release?.call();
    _release = null;
    unawaited(stopTone());
  }

  void dispose() {
    _disposed = true;
    navigation.removeListener(_navigationChanged);
    shownPage.removeListener(_shownChanged);
    cancel();
    revision.dispose();
  }
}
