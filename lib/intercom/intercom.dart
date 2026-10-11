import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum IntercomState {
  idle,
  opening,
  preview,
  connecting,
  talking,
  muted,
  ending,
  error,
}

abstract interface class IntercomTransport {
  Stream<Map<String, dynamic>> get events;
  Future<int> open(int session, Map<String, dynamic> profile);
  Future<bool> permission();
  Future<void> microphone(int session, bool enabled);
  Future<void> volume(int session, double value);
  Future<void> stop(int session);
}

class NativeIntercomTransport implements IntercomTransport {
  static const _channel = MethodChannel('nl.mennovanhout.nspanel/intercom');
  @override
  late final events = const EventChannel(
    'nl.mennovanhout.nspanel/intercomEvents',
  ).receiveBroadcastStream().map((e) => Map<String, dynamic>.from(e as Map));
  @override
  Future<int> open(int session, Map<String, dynamic> profile) async {
    final r = await _channel.invokeMapMethod<String, dynamic>('open', {
      'session': session,
      'profile': profile,
    });
    return (r!['texture'] as num).toInt();
  }

  @override
  Future<bool> permission() async =>
      await _channel.invokeMethod<bool>('permission') ?? false;
  @override
  Future<void> microphone(int session, bool enabled) => _channel.invokeMethod(
    'microphone',
    {'session': session, 'enabled': enabled},
  );
  @override
  Future<void> volume(int session, double value) =>
      _channel.invokeMethod('volume', {'session': session, 'volume': value});
  @override
  Future<void> stop(int session) =>
      _channel.invokeMethod('stop', {'session': session});
}

/// One owner for media, permission intent and temporary display/navigation holds.
class IntercomController extends ChangeNotifier {
  IntercomController(this.transport, {this.onBusy, this.beforeOpen}) {
    _events = transport.events.listen(_event, onError: (_) => _fail('network'));
  }
  final IntercomTransport transport;
  final void Function(bool)? onBusy;
  final Future<void> Function()? beforeOpen;
  late final StreamSubscription<Map<String, dynamic>> _events;
  IntercomState state = IntercomState.idle;
  int _generation = 0;
  int? texture;
  double aspectRatio = 4 / 3;
  double volume = .5;
  String? error;
  Map<String, dynamic> metrics = const {};
  bool _disposed = false;
  bool _busy = false;
  Timer? _timeout;
  bool get inUse => state != IntercomState.idle && state != IntercomState.error;
  bool get busy => _busy;
  void _set(IntercomState next) {
    state = next;
    final hold = {
      IntercomState.opening,
      IntercomState.connecting,
      IntercomState.talking,
      IntercomState.muted,
    }.contains(next);
    if (_busy != hold) {
      _busy = hold;
      onBusy?.call(hold);
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> open(Map<String, dynamic> profile) async {
    if (_disposed || inUse) return;
    final id = ++_generation;
    error = null;
    texture = null;
    metrics = const {};
    _set(IntercomState.opening);
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 10), () {
      if (_generation == id) _fail('timeout');
    });
    try {
      await beforeOpen?.call();
      if (_generation != id || _disposed) return;
      final value = await transport.open(id, profile);
      if (_generation != id || _disposed) {
        await transport.stop(id);
        return;
      }
      texture = value;
      await transport.volume(id, volume);
      if (_generation == id && !_disposed) notifyListeners();
    } catch (e) {
      if (_generation == id) _fail(e is PlatformException ? e.code : 'network');
    }
  }

  Future<void> speak() async {
    if (_disposed ||
        (state != IntercomState.preview && state != IntercomState.muted)) {
      return;
    }
    final previous = state;
    final id = _generation;
    error = null;
    _set(IntercomState.connecting);
    try {
      final allowed = await transport.permission();
      if (_disposed || _generation != id) return;
      if (!allowed) {
        error = 'permission';
        _set(previous);
        return;
      }
      _timeout?.cancel();
      _timeout = Timer(const Duration(seconds: 10), () {
        if (_generation == id) _fail('timeout');
      });
      await transport.microphone(id, true);
    } catch (e) {
      if (_generation == id) _fail(e is PlatformException ? e.code : 'network');
    }
  }

  Future<void> mute() async {
    if (_disposed || state != IntercomState.talking) return;
    final id = _generation;
    try {
      await transport.microphone(id, false);
    } catch (_) {
      if (_generation == id) _fail('audio_device');
    }
  }

  Future<void> setVolume(double value) async {
    volume = value.clamp(0, 1);
    if (!_disposed) notifyListeners();
    if (!inUse) return;
    final id = _generation;
    try {
      await transport.volume(id, volume);
    } catch (_) {
      if (_generation == id) _fail('audio_device');
    }
  }

  void _event(Map<String, dynamic> e) {
    if (_disposed || e['session'] != _generation || !inUse) return;
    switch (e['kind']) {
      case 'preview':
        _timeout?.cancel();
        if (state == IntercomState.opening) _set(IntercomState.preview);
      case 'talking':
        _timeout?.cancel();
        if (state == IntercomState.connecting) _set(IntercomState.talking);
      case 'muted':
        _timeout?.cancel();
        _set(IntercomState.muted);
      case 'video':
        final w = e['width'] as num?, h = e['height'] as num?;
        if (w != null && h != null && w > 0 && h > 0) aspectRatio = w / h;
        notifyListeners();
      case 'metrics':
        metrics = Map.of(e);
        notifyListeners();
      case 'ended':
        unawaited(close());
      case 'error':
        _fail(e['reason']?.toString() ?? 'network');
    }
  }

  void _fail(String reason) {
    if (_disposed) return;
    final id = _generation++;
    _timeout?.cancel();
    texture = null;
    error = reason;
    _set(IntercomState.error);
    unawaited(transport.stop(id).catchError((_) {}));
  }

  Future<void> close() async {
    final id = _generation++;
    _timeout?.cancel();
    texture = null;
    _set(IntercomState.ending);
    try {
      await transport.stop(id);
    } catch (_) {
      /* Android also owns lifecycle teardown. */
    }
    if (_generation == id + 1) _set(IntercomState.idle);
  }

  @override
  void dispose() {
    _disposed = true;
    _timeout?.cancel();
    _events.cancel();
    final id = _generation++;
    if (_busy) onBusy?.call(false);
    unawaited(transport.stop(id).catchError((_) {}));
    super.dispose();
  }
}

String intercomMessage(String? error) => switch (error) {
  'permission' => 'Mikrofon oder DoorBird-Zugriff nicht erlaubt',
  'authentication' => 'DoorBird-Zugang prüfen',
  'locked' => 'Zugang vorübergehend gesperrt',
  'configuration' => 'Privates DoorBird-Profil fehlt oder ist ungültig',
  'busy' => 'DoorBird ist besetzt',
  'timeout' => 'Verbindung unterbrochen oder Zeitüberschreitung',
  'video' => 'Livevideo unterbrochen',
  'audio_focus' => 'Panel-Audio wird anderweitig verwendet',
  'audio_device' => 'Panel-Audio nicht verfügbar',
  'session_expired' => 'Sitzung abgelaufen – bitte neu starten',
  _ => 'Verbindung fehlgeschlagen',
};
