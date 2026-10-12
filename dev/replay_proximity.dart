// Run with dart dev/replay_proximity.dart <private events-*.jsonl[.gz]>.
// Raw data stays outside the repository; output contains aggregates only.
import 'dart:convert';
import 'dart:io';

import 'package:nspanel_app/util/proximity_detector.dart';

Future<void> main(List<String> paths) async {
  final variants = <String, ProximityDetector Function()>{
    for (final f in [2.0, 3.0, 4.0, 5.0, 6.0])
      'adaptive_$f': () =>
          ProximityDetector(adaptive: true, noiseMultiplier: f),
    for (final d in [6.0, 12.0]) 'fixed_$d': () => ProximityDetector(delta: d),
  };
  var detectors = variants.map((k, v) => MapEntry(k, v()));
  final stats = <String, Map<String, dynamic>>{};
  int rows = 0, malformed = 0, duplicate = 0, gaps = 0;
  int? previous;
  for (final path in paths..sort()) {
    Stream<List<int>> bytes = File(path).openRead();
    if (path.endsWith('.gz')) bytes = bytes.transform(gzip.decoder);
    await for (final line
        in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
      Map<String, dynamic> r;
      try {
        r = jsonDecode(line) as Map<String, dynamic>;
      } on FormatException {
        malformed++;
        continue;
      }
      if (r['sensor_clock_reset'] == true) {
        previous = null;
        detectors = variants.map((k, v) => MapEntry(k, v()));
      }
      if (r['sensor_ts'] == null || r['proximity'] is! num) continue;
      final now = (double.parse(r['sensor_ts'].toString()) * 1000).round();
      if (previous != null && now <= previous) {
        duplicate++;
        continue;
      }
      if (previous != null && now - previous > 5000) {
        // We cannot replay unobserved time. Begin a new calibration segment.
        gaps++;
        detectors = variants.map((k, v) => MapEntry(k, v()));
      }
      previous = now;
      rows++;
      final dark = r['display'] == 'OFF';
      final hour = r['received'].toString().substring(0, 13);
      for (final entry in detectors.entries) {
        final d = entry.value;
        d.advance(now);
        d.dark(dark);
        final was = d.near;
        final recoveries = d.recalibrations;
        d.feed((r['proximity'] as num).toDouble(), now);
        if (!dark) continue;
        final s = stats.putIfAbsent(
          '${entry.key}/$hour',
          () => {
            'entries': 0,
            'recalibrations': 0,
            'entry_examples': <Object?>[],
            'thresholds': <double>[],
            'near_samples': 0,
            'samples': 0,
          },
        );
        s['samples']++;
        s['recalibrations'] += d.recalibrations - recoveries;
        if (!was && d.near) {
          s['entries']++;
          final examples = s['entry_examples'] as List<Object?>;
          if (examples.length < 5) {
            examples.add({'received': r['received'], ...?d.lastEntry});
          }
        }
        if (d.near) s['near_samples']++;
        if (d.threshold != null) {
          (s['thresholds'] as List<double>).add(d.threshold!);
        }
      }
    }
  }
  for (final s in stats.values) {
    final a = s.remove('thresholds') as List<double>..sort();
    if (a.isNotEmpty) {
      s['threshold_p50'] = double.parse(a[a.length ~/ 2].toStringAsFixed(2));
      s['threshold_p95'] = double.parse(
        a[(a.length * .95).floor()].toStringAsFixed(2),
      );
    }
    s['near_fraction'] = double.parse(
      (s.remove('near_samples') / s['samples']).toStringAsFixed(4),
    );
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'rows': rows,
      'malformed': malformed,
      'duplicates': duplicate,
      'gaps_over_5s': gaps,
      'note': 'Open-loop replay using actual recorded display state; no physical labels. Entry candidates are not confirmed false wakes. Long gaps restart calibration.',
      'stats': stats,
    }),
  );
}
