import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class HandoffTransport {
  Stream<Map<String, dynamic>> get events;
  Future<bool> available();
  Future<void> begin();
  Future<void> prepared(String session);
  Future<void> finish(String session);
}

class NativeHandoffTransport implements HandoffTransport {
  static const _methods = MethodChannel('local.nspanel/companion_handoff');
  static const _events = EventChannel('local.nspanel/companion_handoff/events');
  @override
  Stream<Map<String, dynamic>> get events => _events
      .receiveBroadcastStream()
      .map((value) => Map<String, dynamic>.from(value as Map));
  @override
  Future<bool> available() async =>
      await _methods.invokeMethod<bool>('available') ?? false;
  @override
  Future<void> begin() => _methods.invokeMethod<void>('begin');
  @override
  Future<void> prepared(String session) =>
      _methods.invokeMethod<void>('prepared', session);
  @override
  Future<void> finish(String session) =>
      _methods.invokeMethod<void>('finish', session);
}

/// Host-independent protocol. Display and navigation are explicit callbacks.
class HandoffController extends ChangeNotifier {
  HandoffController(
    this.transport, {
    required this.acquire,
    required this.prepareReturn,
    required this.release,
  }) {
    _events = transport.events.listen((event) {
      _processing = _processing.then((_) => _event(event)).catchError((
        Object _,
      ) {
        _fail();
      });
    }, onError: (_) => _fail());
  }
  final HandoffTransport transport;
  final VoidCallback acquire, release;
  final Future<void> Function(bool dark) prepareReturn;
  StreamSubscription<Map<String, dynamic>>? _events;
  String? _session;
  final _completed = <String>{};
  Future<void> _processing = Future<void>.value();
  bool active = false, supported = false, _disposed = false, _owned = false;
  String? error;
  Future<void> check() async {
    try {
      supported = await transport.available();
    } catch (_) {
      supported = false;
    }
    if (!_disposed) notifyListeners();
  }

  void _take() {
    if (!_owned) {
      _owned = true;
      acquire();
    }
  }

  void _drop() {
    if (_owned) {
      _owned = false;
      release();
    }
  }

  Future<void> begin() async {
    if (active || _disposed || !supported) return;
    active = true;
    error = null;
    try {
      _take();
      notifyListeners();
      await transport.begin();
    } catch (_) {
      _fail();
    }
  }

  Future<void> _event(Map<String, dynamic> event) async {
    if (_disposed) return;
    final id = event['session'] as String?;
    final state = event['state'];
    if (state == 'idle') return;
    if (id == null ||
        _completed.contains(id) ||
        (_session != null && id != _session)) {
      return;
    }
    _session = id;
    if (state == 'external' || state == 'returning' || state == 'resumed') {
      active = true;
      try {
        _take();
      } catch (_) {
        _fail();
        return;
      }
    }
    if (state == 'returning' || state == 'resumed') {
      try {
        await prepareReturn(event['dark'] == true);
        if (_disposed || _session != id) return;
        if (state == 'returning') {
          await transport.prepared(id);
        } else {
          await transport.finish(id);
          _drop();
          active = false;
          _retire();
        }
      } catch (_) {
        _fail();
      }
    } else if (state == 'error') {
      _fail();
    }
    if (!_disposed) notifyListeners();
  }

  void _retire() {
    final id = _session;
    if (id != null) _completed.add(id);
    if (_completed.length > 64) _completed.remove(_completed.first);
    _session = null;
  }

  void _fail() {
    if (_disposed) return;
    _drop();
    active = false;
    _retire();
    error = 'Home Assistant konnte nicht geöffnet oder zurückgegeben werden.';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _events?.cancel();
    _drop();
    super.dispose();
  }
}
