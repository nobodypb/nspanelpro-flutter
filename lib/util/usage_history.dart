import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Deliberate interactions with original device tiles. No HA payloads or values.
class UsageEvent {
  UsageEvent({
    required this.at,
    required this.entity,
    required this.card,
    required this.page,
    required this.gesture,
    required this.result,
  });

  final int at; // UTC milliseconds
  final String entity;
  String get domain => entity.split('.').first;
  final String card;
  final int page;
  final String gesture;
  String result;

  Map<String, Object> toJson() => {
    'at': at,
    'entity': entity,
    'domain': domain,
    'card': card,
    'page': page,
    'gesture': gesture,
    'result': result,
  };

  static UsageEvent? parse(dynamic raw, int now) {
    if (raw is! Map) return null;
    final at = raw['at'], entity = raw['entity'], card = raw['card'];
    final page = raw['page'], gesture = raw['gesture'], result = raw['result'];
    if (at is! int ||
        at <= now - UsageHistory.windowMs ||
        at > now + 300000 ||
        entity is! String ||
        entity.length > 255 ||
        !UsageHistory.eligible(entity) ||
        raw['domain'] != entity.split('.').first ||
        card is! String ||
        !UsageHistory.cardTypes.contains(card) ||
        page is! int ||
        page < 0 ||
        page > 100 ||
        gesture is! String ||
        !UsageHistory.gestures.contains(gesture) ||
        result is! String ||
        !UsageHistory.results.contains(result)) {
      return null;
    }
    return UsageEvent(
      at: at,
      entity: entity,
      card: card,
      page: page,
      gesture: gesture,
      result: result,
    );
  }
}

class UsageHistory extends ChangeNotifier {
  UsageHistory({int Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  static const windowMs = 30 * 24 * 60 * 60 * 1000;
  static const maxEvents = 10000;
  static const maxBytes = 2 * 1024 * 1024;
  static const domains = {
    'light',
    'switch',
    'input_boolean',
    'fan',
    'cover',
    'climate',
    'media_player',
  };
  static const cardTypes = {
    'nspanel-light-card',
    'nspanel-switch-card',
    'nspanel-cover-card',
    'nspanel-climate-card',
    'nspanel-media-card',
  };
  static const gestures = {'tap', 'hold', 'drag'};
  static const results = {'detail', 'pending', 'success', 'failure', 'unknown'};
  static bool eligible(String entity) {
    final parts = entity.split('.');
    return parts.length == 2 &&
        parts[1].isNotEmpty &&
        domains.contains(parts[0]);
  }

  final int Function() _now;
  final List<UsageEvent> events = [];
  Future<void> Function(String)? _save;
  Future<void> _writes = Future.value();
  String? storageError;

  Future<void> load(String origin, String dashboard) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final key = base64Url
          .encode(utf8.encode('$origin\n$dashboard'))
          .replaceAll('=', '');
      final file = File('${dir.path}/tile-usage-$key.json');
      if (await file.exists()) {
        if (await file.length() <= maxBytes) {
          restore(await file.readAsString());
        } else {
          storageError = 'Usage history exceeded its size limit';
        }
      }
      _save = (raw) async {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(raw, flush: true);
        await tmp.rename(file.path);
      };
    } catch (e) {
      storageError = 'Usage history storage unavailable';
      debugPrint(storageError);
    }
  }

  void restore(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data['version'] != 1 || data['events'] is! List) {
        return;
      }
      final now = _now();
      final newEvents = List<UsageEvent>.of(events);
      events
        ..clear()
        ..addAll(
          (data['events'] as List)
              .map((e) => UsageEvent.parse(e, now))
              .whereType<UsageEvent>(),
        )
        ..addAll(newEvents);
      _bound(now);
      notifyListeners();
    } catch (_) {
      storageError = 'Usage history could not be read';
    }
  }

  String encode() => jsonEncode({
    'version': 1,
    'events': [for (final event in events) event.toJson()],
  });

  UsageEvent? record(
    String entity,
    String card,
    int page,
    String gesture, {
    String result = 'pending',
  }) {
    if (!eligible(entity) ||
        entity.length > 255 ||
        !cardTypes.contains(card) ||
        page < 0 ||
        !gestures.contains(gesture) ||
        !results.contains(result)) {
      return null;
    }
    final now = _now();
    final event = UsageEvent(
      at: now,
      entity: entity,
      card: card,
      page: page,
      gesture: gesture,
      result: result,
    );
    events.add(event);
    _bound(now);
    _persist();
    notifyListeners();
    return event;
  }

  void complete(UsageEvent? event, bool? success) {
    if (event == null || !events.contains(event)) return;
    event.result = success == null
        ? 'unknown'
        : success
        ? 'success'
        : 'failure';
    _persist();
    notifyListeners();
  }

  Map<String, int> counts() {
    if (_bound(_now())) _persist();
    final result = <String, int>{};
    for (final e in events) {
      result.update(e.entity, (n) => n + 1, ifAbsent: () => 1);
    }
    return result;
  }

  void reset() {
    events.clear();
    _persist();
    notifyListeners();
  }

  bool _bound(int now) {
    final before = events.length;
    events.removeWhere((e) => e.at <= now - windowMs || e.at > now + 300000);
    events.sort((a, b) => a.at.compareTo(b.at));
    if (events.length > maxEvents) {
      events.removeRange(0, events.length - maxEvents);
    }
    var bytes = utf8.encode(encode()).length;
    var drop = 0;
    while (bytes > maxBytes && drop < events.length) {
      bytes -= utf8.encode(jsonEncode(events[drop].toJson())).length + 1;
      drop++;
    }
    if (drop > 0) events.removeRange(0, drop);
    return events.length != before;
  }

  void _persist() {
    final save = _save;
    if (save == null) return;
    final raw = encode();
    _writes = _writes.then((_) => save(raw)).catchError((Object _) {
      storageError = 'Usage history could not be saved';
      debugPrint(storageError);
    });
  }

  Future<void> flush() => _writes;
}
