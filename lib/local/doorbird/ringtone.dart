import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

import '../../util/device.dart';

/// Serializes short notifications and restores the user's volume before media.
class DoorBirdRingtone {
  final _player = AudioPlayer();
  Future<void> _pending = Future.value();
  int _generation = 0;
  bool _disposed = false;
  Future<void> wait() async {
    Future<void> last;
    do {
      last = _pending;
      await last;
    } while (!identical(last, _pending));
  }

  Future<void> play() {
    final generation = ++_generation;
    final previous = _pending;
    // Stop playback now; the preceding finally restores its temporary volume.
    final stopped = _player.stop();
    return _pending = () async {
      await stopped;
      await previous;
      if (_disposed || generation != _generation) return;
      int? original;
      var changed = false;
      try {
        original = await Device.volume();
        if (_disposed || generation != _generation) return;
        if (original != null) changed = await Device.setVolume(100);
        await _player.setAsset('assets/sounds/doorbell.wav');
        if (_disposed || generation != _generation) return;
        debugPrint('local ring: standalone volume=100');
        await _player.play().timeout(const Duration(seconds: 5));
      } catch (_) {
        // A failed chime must not prevent camera navigation or leave a hold.
      } finally {
        await _player.stop();
        if (changed && original != null && await Device.volume() == 100) {
          await Device.setVolume(original);
          debugPrint('local ring: volume restored');
        }
      }
    }();
  }

  Future<void> stop() async {
    _generation++;
    await _player.stop();
    await _pending;
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _player.dispose();
  }
}
