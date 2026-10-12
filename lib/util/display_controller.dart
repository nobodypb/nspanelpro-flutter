import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/screensaver.dart';

abstract interface class DisplayDriver {
  Future<bool> off();
  Future<void> on();
  Future<void> holdCpu(bool on);
  Future<void> saver(bool on);
  Future<void> idleTimeout(int? milliseconds);
}

/// One owner for the dashboard, every dialog, and the physical display.
/// Timers use Dart's monotonic timer queue; transitions invalidate pending I/O.
class DisplayController extends ChangeNotifier {
  DisplayController(this.driver);
  final DisplayDriver driver;
  ScreensaverConfig? config;
  bool enabled = false, foreground = true, interactive = true;
  bool saving = false, near = false;
  int fingers = 0;
  int touchSerial = 0;
  bool _screenOnForSaver = false;
  bool _disposed = false, _forced = false, _nearBlocked = false;
  bool _observed = false, _busy = false;
  bool _external = false, _externalReturn = false;
  bool get externalSession => _external;
  bool get _ownsDisplay => _external ? _externalReturn : foreground;

  /// A temporary external owner uses Android idle while detection stays warm.
  /// Only this lease can authorize dark return before the activity resumes.
  ExternalDisplayLease beginExternalSession() {
    if (_external || _holds > 0) {
      throw StateError('Display cannot be handed over now');
    }
    _external = true;
    _externalReturn = false;
    _generation++;
    _cancelTimers();
    notifyListeners();
    return ExternalDisplayLease._(this);
  }

  Future<void> _prepareExternalReturn(bool dark) async {
    if (_disposed || !_external) return;
    _externalReturn = true;
    if (dark) {
      interactive = false;
      saving = true;
      _wantDark = true;
      _nearBlocked = near;
      _generation++;
      await driver.saver(true);
      await driver.holdCpu(true);
    }
    notifyListeners();
  }

  void _endExternalSession() {
    if (_disposed || !_external) return;
    _external = false;
    _externalReturn = false;
    _arm();
    notifyListeners();
  }

  bool _wantDark = false;
  int _generation = 0;
  Timer? _idle, _darkTimer;
  ScreensaverConfig get effective => config ?? const ScreensaverConfig();
  int _holds = 0;
  VoidCallback hold() {
    _holds++;
    _cancelTimers();
    wake();
    bool released = false;
    return () {
      if (released || _disposed) return;
      released = true;
      _holds--;
      if (_holds == 0) _arm();
    };
  }

  bool get canIdle =>
      _holds == 0 &&
      enabled &&
      foreground &&
      !_external &&
      fingers == 0 &&
      !(effective.keepAwakeOnProximity && near && !_nearBlocked);

  void configure(ScreensaverConfig? next, {required bool active}) {
    final before = config;
    final changed =
        enabled != active ||
        before?.afterSeconds != next?.afterSeconds ||
        before?.sleep != next?.sleep ||
        before?.sleepAfterSeconds != next?.sleepAfterSeconds ||
        before?.keepAwakeOnProximity != next?.keepAwakeOnProximity;
    config = next;
    unawaited(
      driver.idleTimeout(
        active && next != null
            ? next.afterSeconds.clamp(10, 86400) * 1000
            : null,
      ),
    );
    final wasEnabled = enabled;
    enabled = active;
    if (active && !wasEnabled && !interactive && next?.sleep == true) {
      saving = true;
      _wantDark = true;
      unawaited(driver.saver(true));
      unawaited(driver.holdCpu(true));
    }
    if (!active) {
      _cancelTimers();
      _wantDark = false;
      _generation++;
      saving = false;
      _forced = false;
      unawaited(driver.saver(false));
      unawaited(driver.holdCpu(false));
    } else if (changed) {
      if (saving) {
        _darkTimer?.cancel();
        _darkTimer = null;
        if (!effective.sleep) {
          _wantDark = false;
          _screenOnForSaver = !interactive;
          _generation++;
          _reconcile();
        } else if (interactive) {
          _scheduleDark();
        }
      } else {
        _arm();
      }
    }
    notifyListeners();
  }

  void platform({
    required String kind,
    required bool screenOn,
    required bool inForeground,
    required int pointerCount,
  }) {
    if (_disposed) return;
    final wasOn = interactive;
    final wasForeground = foreground;
    final initial = !_observed;
    _observed = true;
    interactive = screenOn;
    foreground = inForeground;
    fingers = pointerCount;
    if (kind == 'touch') touchSerial++;
    if (!_ownsDisplay) {
      _cancelTimers();
      _generation++;
      _wantDark = false;
      unawaited(driver.holdCpu(false));
      notifyListeners();
      return;
    }
    if (!screenOn && enabled) {
      // External sleep and cold starts in the dark join the same state.
      _idle?.cancel();
      saving = true;
      unawaited(driver.saver(true));
      unawaited(driver.holdCpu(true));
      if (wasOn && !_wantDark) _nearBlocked = near;
    }
    if (screenOn && !wasOn && _screenOnForSaver) {
      _screenOnForSaver = false;
      unawaited(driver.holdCpu(false));
    } else if (kind == 'wake' ||
        (screenOn && !wasOn) ||
        (initial && screenOn)) {
      wake();
    } else if (kind == 'touch') {
      if (saving) {
        wake();
      } else {
        _arm();
      }
    } else if (!wasForeground && foreground && screenOn) {
      // No extra guard here: Android owns wake transition detection.
      if (saving) {
        wake();
      } else {
        _arm();
      }
    }
    notifyListeners();
  }

  void proximity(bool value) {
    if (_disposed || near == value) return;
    near = value;
    if (!near) _nearBlocked = false;
    if (enabled && _ownsDisplay) {
      if (near && effective.wakeOnProximity && !_nearBlocked) {
        wake();
      } else if (!saving) {
        _arm();
      }
    }
    notifyListeners();
  }

  void wake() {
    if (_disposed || !enabled || !_ownsDisplay) return;
    _forced = false;
    _screenOnForSaver = false;
    _nearBlocked = false;
    _wantDark = false;
    _generation++;
    _darkTimer?.cancel();
    _darkTimer = null;
    saving = false;
    unawaited(driver.saver(false));
    _reconcile();
    if (interactive && !_busy) unawaited(driver.holdCpu(false));
    _arm();
    notifyListeners();
  }

  void sleep({bool force = false}) {
    if (_disposed ||
        !enabled ||
        !foreground ||
        (!force && (!canIdle || config == null))) {
      return;
    }
    _idle?.cancel();
    _forced = force;
    _nearBlocked = force && near;
    saving = true;
    // Native gate must know about the overlay before it is displayed.
    final generation = ++_generation;
    unawaited(
      driver.saver(true).then((_) {
        if (_disposed || generation != _generation || !saving) return;
        notifyListeners();
        _scheduleDark();
      }),
    );
  }

  void _scheduleDark() {
    _darkTimer?.cancel();
    if (!effective.sleep || !saving) return;
    _darkTimer = Timer(Duration(seconds: effective.sleepAfterSeconds), () {
      if (!saving || !foreground || (!canIdle && !_forced)) return;
      _wantDark = true;
      _generation++;
      _reconcile();
    });
  }

  void _arm() {
    _idle?.cancel();
    if (!canIdle || saving || config == null) return;
    _idle = Timer(
      Duration(seconds: effective.afterSeconds.clamp(10, 86400)),
      sleep,
    );
  }

  /// Serialize shell/wake operations and undo a sleep overtaken by new input.
  void _reconcile() {
    if (_busy || _disposed) return;
    _busy = true;
    unawaited(() async {
      try {
        while (!_disposed) {
          final generation = _generation;
          if (_wantDark && interactive && enabled && foreground) {
            final off = await driver.off();
            if (off) {
              interactive = false;
              if ((_disposed || !enabled || !foreground) && !_external) {
                await driver.on();
                await driver.holdCpu(false);
              }
            } else {
              _wantDark = false;
              debugPrint('display: sleep failed; screensaver remains visible');
            }
          } else if (!_wantDark && !interactive && enabled && _ownsDisplay) {
            await driver.on();
            // Actual state is confirmed by Android's screen event.
          }
          if (generation == _generation) break;
        }
      } catch (e) {
        debugPrint('display: transition failed (${e.runtimeType})');
      } finally {
        _busy = false;
        if (!_disposed) notifyListeners();
      }
    }());
  }

  void _cancelTimers() {
    _idle?.cancel();
    _darkTimer?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelTimers();
    unawaited(driver.holdCpu(false));
    super.dispose();
  }
}

/// Scoped display handoff. Releasing it never wakes the screen.
class ExternalDisplayLease {
  ExternalDisplayLease._(this._owner);
  DisplayController? _owner;
  Future<void> prepareReturn({required bool dark}) async {
    await _owner?._prepareExternalReturn(dark);
  }

  void release() {
    final owner = _owner;
    _owner = null;
    owner?._endExternalSession();
  }
}
