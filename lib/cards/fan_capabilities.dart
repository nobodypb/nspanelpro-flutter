import '../ha/states.dart';

/// HA's fan flags are independent: speed control does not imply turn_on.
class FanCapabilities {
  FanCapabilities(HaState? state) {
    final attrs = state?.attributes ?? const <String, dynamic>{};
    final raw = attrs['supported_features'];
    final flags =
        state?.domain == 'fan' && raw is num && raw.isFinite && raw >= 0
        ? raw.toInt()
        : 0;
    speed = flags & 1 != 0;
    turnOff = flags & 16 != 0;
    turnOn = flags & 32 != 0;
    final modes = attrs['preset_modes'];
    // HA also accepts presets on older SET_SPEED fans, if they list modes.
    presets = flags & 9 != 0 && modes is List
        ? modes
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .toSet()
              .toList()
        : const [];
    final step = attrs['percentage_step'];
    final count = step is num && step.isFinite && step > 0 && step <= 100
        ? (100 / step.clamp(1, 100)).round().clamp(1, 100)
        : 100;
    // Match HA's integer percentage conversion, including three-speed fans.
    levels = [for (var i = 0; i <= count; i++) (i * 100 / count).floor()];
  }

  late final bool speed, turnOn, turnOff;
  late final List<String> presets;
  late final List<int> levels;

  int snap(double percentage) {
    if (!percentage.isFinite) return 0;
    return levels.reduce(
      (a, b) => (a - percentage).abs() < (b - percentage).abs() ? a : b,
    );
  }
}
