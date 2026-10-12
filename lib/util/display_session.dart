import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/screensaver.dart';
import 'device.dart';
import 'display.dart';
import 'display_controller.dart';
import 'proximity.dart';
import 'proximity_presence.dart';
import 'panel_trace.dart';

class NativeDisplayDriver implements DisplayDriver {
  final _power = DisplayPower();
  static const _control = MethodChannel(
    'nl.mennovanhout.nspanel/displayControl',
  );
  @override
  Future<void> idleTimeout(int? milliseconds) async {
    try {
      await _control.invokeMethod<void>('idleTimeout', milliseconds);
    } on MissingPluginException {
      /* Non-Android host. */
    }
  }

  @override
  Future<bool> off() => _power.off();
  @override
  Future<void> on() => _power.on();
  @override
  Future<void> holdCpu(bool on) => Device.holdCpu(on);
  @override
  Future<void> saver(bool on) async {
    try {
      await _control.invokeMethod<void>('saver', on);
    } on MissingPluginException {
      /* Widget tests and non-Android hosts. */
    }
  }
}

/// App-lifetime platform subscriptions; no dependency on HA or MQTT sockets.
class DisplaySession {
  DisplaySession() {
    controller.addListener(_changed);
    _events = const EventChannel('nl.mennovanhout.nspanel/displayEvents')
        .receiveBroadcastStream()
        .listen(
          (dynamic event) {
            final e = event as Map;
            final stamp = e['elapsed'];
            if (stamp is num) {
              _elapsed = stamp.toInt();
              _clock.reset();
            }
            lastEvent = Map<String, dynamic>.from(e);
            activity.add(lastEvent!);
            controller.platform(
              kind: e['kind'] as String,
              screenOn: e['interactive'] == true,
              inForeground: e['foreground'] == true,
              pointerCount: (e['fingers'] as num?)?.toInt() ?? 0,
            );
          },
          onError: (Object e) => debugPrint(
            'display: platform stream unavailable (${e.runtimeType})',
          ),
        );
  }
  final activity = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  Map<String, dynamic>? lastEvent;
  final _clock = Stopwatch()..start();
  int _elapsed = 0;
  int get elapsedMilliseconds => _elapsed + _clock.elapsedMilliseconds;
  final controller = DisplayController(NativeDisplayDriver());
  StreamSubscription<dynamic>? _events;
  StreamSubscription<double>? _sensor;
  ProximityPresence? _presence;
  ScreensaverConfig? _sensorConfig;
  Map<String, Object?> get proximityDiagnostics => {
    'mode': _presence == null
        ? 'inactive'
        : _sensorConfig!.proximityAbove != null ||
              _sensorConfig!.proximityBelow != null
        ? 'absolute'
        : _sensorConfig!.proximityAdaptive
        ? 'adaptive'
        : 'fixed',
    'baseline': _presence?.detector.baseline,
    'noise': _presence?.detector.noise,
    'threshold': _presence?.detector.threshold,
    'near': _presence?.near ?? false,
    'dark': !controller.interactive,
    'entries': _presence?.detector.entries ?? 0,
    'recalibrations': _presence?.detector.recalibrations ?? 0,
    'last_entry': _presence?.detector.lastEntry,
  };
  bool _disposed = false;
  bool _updating = false;

  void configure(ScreensaverConfig? config, {required bool active}) {
    controller.configure(config, active: active);
    _changed();
  }

  void _changed() {
    if (_disposed || _updating) return;
    _updating = true;
    try {
      _updateSensor();
    } finally {
      _updating = false;
    }
  }

  void _updateSensor() {
    final s = controller.config;
    if (!controller.enabled ||
        !controller.foreground ||
        s == null ||
        (!s.wakeOnProximity && !s.keepAwakeOnProximity)) {
      if (_presence != null) {
        PanelTrace.record('detector', {'reason': 'stopped'});
      }
      _sensor?.cancel();
      _sensor = null;
      _presence?.dispose();
      _presence = null;
      _sensorConfig = null;
      controller.proximity(false);
      return;
    }
    final old = _sensorConfig;
    if (_sensor == null ||
        old?.proximityAbove != s.proximityAbove ||
        old?.proximityBelow != s.proximityBelow ||
        old?.proximityDelta != s.proximityDelta ||
        old?.proximityAdaptive != s.proximityAdaptive ||
        old?.proximityNoiseMultiplier != s.proximityNoiseMultiplier ||
        old?.proximityRecalibrateSeconds != s.proximityRecalibrateSeconds) {
      _sensor?.cancel();
      _presence?.dispose();
      _sensorConfig = s;
      controller.proximity(false);
      PanelTrace.record('detector', {
        'reason': old == null ? 'started' : 'reconfigured',
        'adaptive': s.proximityAdaptive,
        'multiplier': s.proximityNoiseMultiplier,
        'delay_seconds': s.proximityRecalibrateSeconds,
      });
      final detector = ProximityPresence(
        s,
        controller.proximity,
        onTrace: PanelTrace.record,
      );
      _presence = detector;
      _sensor = Proximity.stream.listen(
        detector.feed,
        onError: (Object e) {
          debugPrint('display: proximity unavailable (${e.runtimeType})');
          controller.proximity(false);
        },
      );
    }
    _presence?.dark(!controller.interactive);
  }

  void dispose() {
    _disposed = true;
    _events?.cancel();
    _sensor?.cancel();
    _presence?.dispose();
    controller.removeListener(_changed);
    activity.close();
    controller.dispose();
  }
}
