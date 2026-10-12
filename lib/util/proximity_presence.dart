import 'dart:async';

import '../config/screensaver.dart';
import 'proximity_detector.dart';

/// App-lifetime adapter; the pure detector is also used by offline replay.
class ProximityPresence {
  ProximityPresence(
    ScreensaverConfig config,
    this.onChanged, {
    void Function(String, Map<String, Object?>)? onTrace,
    int Function()? now,
  }) : _nowOverride = now,
       detector = ProximityDetector(
         onTrace: onTrace,
         delta: config.proximityDelta,
         above: config.proximityAbove,
         below: config.proximityBelow,
         adaptive: config.proximityAdaptive,
         noiseMultiplier: config.proximityNoiseMultiplier,
         recalibrateSeconds: config.proximityRecalibrateSeconds,
       );

  final void Function(bool) onChanged;
  final ProximityDetector detector;
  final _clock = Stopwatch()..start();
  final int Function()? _nowOverride;
  int get _now => _nowOverride?.call() ?? _clock.elapsedMilliseconds;
  Timer? _leave;
  int? _scheduledLeave;
  bool _reported = false;
  bool get near => detector.near;
  int? get modelAgeMs => detector.modelAgeAt(_now);
  int? get baselineAgeMs => detector.baselineAgeAt(_now);

  void dark(bool value) {
    detector.dark(value, now: _now);
    _sync();
  }

  void touch() => detector.touch(_now);

  void feed(double value) {
    detector.feed(value, _now);
    _sync();
  }

  void _sync() {
    if (_scheduledLeave != detector.leaveAt) {
      _leave?.cancel();
      _scheduledLeave = detector.leaveAt;
      final at = _scheduledLeave;
      if (at != null) {
        _leave = Timer(Duration(milliseconds: (at - _now).clamp(0, 500)), () {
          detector.advance(at);
          _sync();
        });
      }
    }
    if (_reported != detector.near) {
      _reported = detector.near;
      onChanged(_reported);
    }
  }

  void dispose() {
    _leave?.cancel();
    _clock.stop();
  }
}
