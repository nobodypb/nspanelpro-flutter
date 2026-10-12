import 'dart:async';

import 'package:flutter/services.dart';

/// Fixed diagnostic fields only; never UI contents, coordinates or credentials.
class PanelTrace {
  static const _channel = MethodChannel('nl.mennovanhout.nspanel/panelTrace');
  static void record(String event, Map<String, Object?> fields) {
    unawaited(_send(event, fields));
  }

  static Future<void> _send(String event, Map<String, Object?> fields) async {
    try {
      await _channel.invokeMethod<void>('record', {
        'event': event,
        'fields': fields,
      });
    } on MissingPluginException {
      // Tests and non-Android hosts.
    } on PlatformException {
      // Diagnostics must never change display behaviour.
    }
  }
}
