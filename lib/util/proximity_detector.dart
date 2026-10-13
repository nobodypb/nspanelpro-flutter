import 'dart:math' as math;

/// Pure detector shared by the live display controller and offline replay.
/// Times are monotonic milliseconds; silence never implies absence.
class ProximityDetector {
  ProximityDetector({
    this.delta = 12,
    this.above,
    this.below,
    this.adaptive = false,
    this.noiseMultiplier = 4,
    this.recalibrateSeconds = 30,
    this.onTrace,
  });

  final void Function(String, Map<String, Object?>)? onTrace;
  final double delta;
  final double? above, below;
  final bool adaptive;
  final double noiseMultiplier;
  final int recalibrateSeconds;
  bool near = false, _dark = false;
  int _hits = 0, _direction = 0;
  int? _lastAt;
  int? leaveAt;
  int entries = 0, recalibrations = 0;
  bool _strong = false;
  int _strongHits = 0, _strongDirection = 0;
  int? _weakAfterStrong;
  // Evidence belongs to a display model, not to the current near episode.
  final _weak = <bool, _WeakEvidence>{};
  int? _darkAt, _rapidAt;
  double? _rapidValue;
  int _repetitions = 0;
  int get _now => _lastAt ?? 0;
  int? modelAgeAt(int now) =>
      _model == null ? null : (now - _model!.createdAt).clamp(0, 1 << 53);
  int? baselineAgeAt(int now) =>
      _model == null ? null : (now - _model!.trustedAt).clamp(0, 1 << 53);
  int? get modelAgeMs => modelAgeAt(_now);
  int? get baselineAgeMs => baselineAgeAt(_now);
  Map<String, Object?>? lastEntry;
  final _models = <bool, _RestModel>{};
  final _samples = <double>[];

  _RestModel? get _model => _models[_dark] ?? (near ? _models[!_dark] : null);
  double? get baseline => _model?.base;
  double? get noise => adaptive ? _model?.noise : null;
  double? get threshold {
    if (above != null || below != null) return null;
    final m = _model;
    if (m == null) return null;
    return adaptive
        ? math.max(2, noiseMultiplier * m.noise)
        : math.max(delta, m.base.abs() * .15);
  }

  void dark(bool value, {int? now}) {
    if (_dark == value) return;
    _dark = value;
    _darkAt = now ?? _now;
    _samples.clear();
    _hits = _strongHits = 0;
    _weakAfterStrong = null;
    leaveAt = null;
    // Preserve the other model's candidate; never mix its samples.
    // Do not let time spent in the other display state advance learning.
    _models[_dark]?.resume(clear: true);
  }

  /// Finish the leave debounce even if an on-change sensor sends no new value.
  void advance(int now) {
    if (leaveAt != null && now >= leaveAt!) {
      near = false;
      onTrace?.call('proximity', {
        'reason': 'leave',
        'detector_ms': now,
        'dark': _dark,
      });
      leaveAt = null;
      _hits = 0;
      // Resume the quiet window without adding readings taken while near.
      // Keep short unconfirmed excursions so repeated interference is learned.
      for (final m in _models.values) {
        m.resume();
      }
    }
  }

  void feed(double value, int now) {
    if (!value.isFinite) return;
    advance(now);
    final gap = _lastAt == null ? 0 : now - _lastAt!;
    _lastAt = now;
    if (gap < 0 || gap > 2000) {
      _hits = 0;
      _samples.clear();
      _clearEvidence('sensor_gap', now);
      for (final m in _models.values) {
        m.resume(clear: true);
      }
    }
    if (gap < 0 || gap > 1000) {
      _strongHits = 0;
      _weakAfterStrong = null;
    }
    double? evaluatedThreshold, evaluatedBase;
    bool enter, leave;
    if (above != null || below != null) {
      enter =
          (above != null && value > above!) ||
          (below != null && value < below!);
      leave =
          (above == null || value < above! * .8) &&
          (below == null || value > below! * 1.2);
    } else {
      var model = _model;
      if (model == null) {
        // Do not initialise a new display state from a known near reading.
        if (near) return;
        _samples.add(value);
        if (_samples.length < 20) return;
        model = _models[_dark] = _RestModel(_samples, now);
        _samples.clear();
        _calibration('initial', now, null);
      }
      final difference = value - model.base;
      final limit = threshold!;
      evaluatedThreshold = limit;
      evaluatedBase = model.base;
      enter = difference.abs() > limit;
      leave = difference.abs() < limit * .8;
      if (adaptive && enter) {
        final direction = difference > 0 ? 1 : -1;
        if (direction != _direction || gap > 1000) _hits = 0;
        _direction = direction;
      }
      if (adaptive) {
        final direction = difference > 0 ? 1 : -1;
        if (direction != _strongDirection) _strongHits = 0;
        _strongDirection = direction;
        _strongHits = difference.abs() > limit * 2 ? _strongHits + 1 : 0;
        if (!near && _hits == 0) _strong = false;
        if (_strongHits >= 2) {
          _strong = true;
          _clearEvidence('strong', now);
        }
        // A historical strong approach must not protect a later weak plateau
        // forever. Require two seconds of fresh, continuously non-strong data;
        // only then can a NEW full recovery interval begin.
        if (_strong && difference.abs() <= limit * 2) {
          _weakAfterStrong ??= now;
          if (now - _weakAfterStrong! >= 2000) _strong = false;
        } else {
          _weakAfterStrong = null;
        }
        if (near && !_strong && !leave && recalibrateSeconds > 0) {
          _weak.putIfAbsent(_dark, () => _WeakEvidence(now, difference));
        }
        if (_recoverWeak(value, now, model, leave: leave)) return;
      }
      if (!near) {
        if (adaptive) {
          // Include unconfirmed excursions in robust noise estimation to
          // avoid systematically censoring the upper part of the noise.
          model.learn(value, now, moveBase: !enter);
        } else if (!enter) {
          model.base = model.base * .99 + value * .01;
        }
      }
    }
    if (!near) {
      _hits = enter ? _hits + 1 : 0;
      if (_hits >= 2) {
        near = true;
        entries++;
        if (adaptive && !_strong && recalibrateSeconds > 0) {
          final evidence = _weak.putIfAbsent(
            _dark,
            () => _WeakEvidence(now, value - (baseline ?? value)),
          );
          evidence.add(value, now);
          _repeat(value, now);
        }
        lastEntry = {
          'elapsed_ms': now,
          'value': value,
          'baseline': evaluatedBase,
          'threshold': evaluatedThreshold,
          'dark': _dark,
          'model_age_ms': modelAgeMs,
          'baseline_age_ms': baselineAgeMs,
        };
        onTrace?.call('proximity', {
          'reason': 'enter',
          'detector_ms': now,
          'value': value,
          'baseline': evaluatedBase,
          'threshold': evaluatedThreshold,
          'dark': _dark,
          'model_age_ms': modelAgeMs,
          'baseline_age_ms': baselineAgeMs,
        });
        _hits = 0;
      }
    } else if (leave) {
      leaveAt ??= now + 500;
    } else {
      leaveAt = null;
    }
  }

  void _calibration(String reason, int now, double? previous) {
    onTrace?.call('calibration', {
      'reason': reason,
      'detector_ms': now,
      'dark': _dark,
      'old_baseline': previous,
      'baseline': baseline,
      'noise': noise,
      'threshold': threshold,
      'delay_seconds': recalibrateSeconds,
      'model_age_ms': modelAgeMs,
      'baseline_age_ms': baselineAgeMs,
    });
  }

  /// A touch is positive activity, so do not calibrate from its approach.
  void touch(int now) => _clearEvidence('touch', now);

  void _clearEvidence(String reason, int now) {
    if (_weak.isNotEmpty) {
      onTrace?.call('recovery', {'reason': reason, 'detector_ms': now});
    }
    _weak.clear();
    _rapidAt = null;
    _rapidValue = null;
    _repetitions = 0;
  }

  void _repeat(double value, int now) {
    if (!_dark || _darkAt == null || now - _darkAt! > 2000) return;
    final similar =
        _rapidAt != null &&
        now - _rapidAt! <= 120000 &&
        (value - _rapidValue!).abs() <= math.max(4, (noise ?? 1) * 2);
    _repetitions = similar ? _repetitions + 1 : 1;
    _rapidAt = now;
    _rapidValue = value;
    onTrace?.call('repetition', {
      'reason': 'off_near',
      'detector_ms': now,
      'count': _repetitions,
      'value': value,
      'baseline': baseline,
      'threshold': threshold,
      'model_age_ms': modelAgeMs,
      'baseline_age_ms': baselineAgeMs,
      'since_switch_ms': now - _darkAt!,
      'suppressed': false,
    });
  }

  bool _recoverWeak(
    double value,
    int now,
    _RestModel model, {
    required bool leave,
  }) {
    final evidence = _weak[_dark];
    if (evidence == null || _strong || recalibrateSeconds <= 0) return false;
    final maxAge = math.max(10000, recalibrateSeconds * 1000);
    if (now - evidence.lastAt > maxAge) {
      _weak.remove(_dark);
      onTrace?.call('recovery', {
        'reason': 'expired',
        'detector_ms': now,
        'dark': _dark,
      });
      return false;
    }
    if (leave) {
      evidence.restSince ??= now;
      if (now - evidence.restSince! >= 500) {
        _weak.remove(_dark);
        onTrace?.call('recovery', {
          'reason': 'restored',
          'detector_ms': now,
          'dark': _dark,
        });
      }
      return false;
    }
    evidence.restSince = null;
    if ((value - model.base).sign != evidence.direction) {
      _weak.remove(_dark);
      onTrace?.call('recovery', {
        'reason': 'direction',
        'detector_ms': now,
        'dark': _dark,
      });
      return false;
    }
    evidence.add(value, now);
    evidence.samples.removeWhere((s) => now - s.at > maxAge);
    if (now - evidence.since < recalibrateSeconds * 1000 ||
        evidence.samples.length < 20 ||
        evidence.samples.where((s) => now - s.at <= 1500).length < 3) {
      return false;
    }
    final values = [for (final sample in evidence.samples) sample.value];
    final sorted = [...values]..sort();
    final spread =
        sorted[((sorted.length - 1) * .9).floor()] -
        sorted[((sorted.length - 1) * .1).floor()];
    if (spread > math.max(4, model.noise * 4)) return false;
    // Require fresh support in this state; inactive time alone never calibrates.
    // The clock survives display transitions, while every sample keeps its state.
    final rest = _RestModel(values, now);
    rest.noise = math.max(model.noise, rest.noise);
    _models[_dark] = rest;
    recalibrations++;
    onTrace?.call('recovery', {
      'reason': 'ready',
      'detector_ms': now,
      'dark': _dark,
      'evidence_ms': now - evidence.since,
      'sample_count': values.length,
      'previous_model_age_ms': now - model.createdAt,
      'previous_baseline_age_ms': now - model.trustedAt,
    });
    _calibration('weak_stable', now, model.base);
    onTrace?.call('proximity', {
      'reason': 'recalibrated_leave',
      'detector_ms': now,
      'dark': _dark,
    });
    near = false;
    leaveAt = null;
    _hits = _strongHits = 0;
    _weak.remove(_dark);
    return true;
  }
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

double _scale(List<double> values) {
  final center = _median(values);
  final deviations = [for (final v in values) (v - center).abs()]..sort();
  // Combine central MAD with the 90th percentile so frequent short bursts
  // cannot hide behind a quiet median. The upper 10% cannot set this scale.
  // Constants normalise a Gaussian distribution; no Gaussian assumption or
  // false-wake probability is claimed for this sensor's correlated noise.
  return math.max(
    1,
    math.max(
      1.4826 * _median(deviations),
      deviations[((deviations.length - 1) * .9).floor()] / 1.645,
    ),
  );
}

class _RestModel {
  _RestModel(List<double> samples, int now)
    : base = ([...samples]..sort())[samples.length ~/ 2],
      noise = _scale(samples),
      _lastAt = now,
      _noiseAt = now,
      createdAt = now,
      trustedAt = now;

  final int createdAt;
  int trustedAt;
  double base, noise;
  final _residuals = <double>[];
  int? _lastAt, _noiseAt, _sampleAt;

  void resume({bool clear = false}) {
    _lastAt = _sampleAt = null;
    if (clear) {
      _noiseAt = null;
      _residuals.clear();
    }
  }

  void learn(double value, int now, {required bool moveBase}) {
    final dt = _lastAt == null ? 0 : (now - _lastAt!).clamp(0, 1000);
    _lastAt = now;
    // At most 10 observations/s and 64 values per display state. Bursts cannot
    // consume a whole learning window. Statistics are recomputed once/second.
    if (_sampleAt == null || now - _sampleAt! >= 100) {
      _sampleAt = now;
      _residuals.add(value - base);
      if (_residuals.length > 64) _residuals.removeAt(0);
    }
    _noiseAt ??= now;
    if (_residuals.length >= 20 && now - _noiseAt! >= 1000) {
      final target = _scale(_residuals);
      final seconds = (now - _noiseAt!).clamp(0, 2000) / 1000;
      final tau = target > noise ? 2 : 60;
      noise += (target - noise) * (1 - math.exp(-seconds / tau));
      _noiseAt = now;
    }
    // Freeze as soon as an approach is suspected, before its confirmation.
    // Time-based learning avoids changing behaviour with the sample rate.
    if (moveBase) {
      base += (value - base) * (1 - math.exp(-dt / 10000));
      trustedAt = now;
    }
  }
}

class _WeakEvidence {
  _WeakEvidence(this.since, double difference)
    : direction = difference.sign,
      lastAt = since;
  final int since;
  final double direction;
  int? restSince;
  int lastAt;
  final samples = <({double value, int at})>[];
  void add(double value, int now) {
    if (samples.isNotEmpty && now - samples.last.at < 100) return;
    lastAt = now;
    samples.add((value: value, at: now));
    if (samples.length > 64) samples.removeAt(0);
  }
}
