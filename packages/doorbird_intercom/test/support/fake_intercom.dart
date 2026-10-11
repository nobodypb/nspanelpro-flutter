import 'dart:async';

import 'package:doorbird_intercom/doorbird_intercom.dart';

class FakeIntercom implements IntercomTransport {
  final stream = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final calls = <String>[];
  int id = 0;
  Completer<bool>? permissionReply;
  Completer<int>? openReply;
  bool allowed = true;
  @override
  Stream<Map<String, dynamic>> get events => stream.stream;
  void emit(String kind, {int? session}) =>
      stream.add({'kind': kind, 'session': session ?? id});
  @override
  Future<int> open(int session, Map<String, dynamic> profile) async {
    id = session;
    calls.add('open');
    return openReply == null ? 1 : await openReply!.future;
  }

  @override
  Future<bool> permission() async {
    calls.add('permission');
    return permissionReply == null ? allowed : await permissionReply!.future;
  }

  @override
  Future<void> microphone(int session, bool enabled) async {
    calls.add('mic:$enabled');
    emit(enabled ? 'talking' : 'muted', session: session);
  }

  @override
  Future<void> volume(int session, double value) async {
    calls.add('volume:$value');
  }

  @override
  Future<void> stop(int session) async {
    calls.add('stop:$session');
  }
}
