import 'package:flutter/material.dart';

import '../config/dashboard.dart';
import '../ha/states.dart';
import '../ui/theme.dart';
import '../util/color.dart';
import 'env.dart';
import 'fan_capabilities.dart';

/// Self-contained so fan details work on upstream without other card changes.
Future<void> showFanSheet(
  BuildContext context,
  CardConfig config,
  PanelEnv env,
) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close fan details',
  barrierColor: Ns.ground.withValues(alpha: .72),
  transitionDuration: const Duration(milliseconds: 180),
  transitionBuilder: (_, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
  pageBuilder: (_, _, _) => FanSheet(config: config, env: env),
);

class FanSheet extends StatefulWidget {
  const FanSheet({super.key, required this.config, required this.env});
  final CardConfig config;
  final PanelEnv env;

  @override
  State<FanSheet> createState() => _FanSheetState();
}

class _FanSheetState extends State<FanSheet> {
  String get entity => widget.config.str('entity') ?? '';
  double? _drag;
  bool _dragCancelled = false;
  bool _busy = false;
  bool _failed = false;

  Future<void> _send(
    String service, [
    Map<String, dynamic> data = const {},
  ]) async {
    final state = widget.env.states.get(entity);
    if (_busy || state == null || state.isBroken || !widget.env.conn.isOnline) {
      return;
    }
    final caps = FanCapabilities(state);
    // Recheck live capabilities at dispatch, including changes during a drag.
    final allowed = switch (service) {
      'turn_on' => caps.turnOn,
      'turn_off' => caps.turnOff,
      'set_percentage' => caps.speed,
      'set_preset_mode' => caps.presets.contains(data['preset_mode']),
      _ => false,
    };
    if (!allowed) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await widget.env.conn.callService('fan', service, {
      'entity_id': entity,
      ...data,
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !ok;
    });
  }

  void _commit(double value) {
    setState(() => _drag = null);
    final caps = FanCapabilities(widget.env.states.get(entity));
    _send('set_percentage', {'percentage': caps.snap(value)});
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.env.states.listen(entity),
      widget.env.conn.status,
    ]),
    builder: (_, _) {
      final state = widget.env.states.get(entity);
      final caps = FanCapabilities(state);
      final available =
          state != null && !state.isBroken && widget.env.conn.isOnline;
      final enabled = available && !_busy;
      if (!enabled || !caps.speed) {
        _drag = null;
        _dragCancelled = true;
      }
      final raw = state?.attributes['percentage'];
      final actual = raw is num && raw.isFinite
          ? raw.toDouble().clamp(0.0, 100.0)
          : 0.0;
      final value = enabled ? _drag ?? actual : actual;
      final preset = state?.attr<String>('preset_mode');
      final status = !available
          ? 'Unavailable'
          : state.isOn
          ? 'On'
          : 'Off';
      final accent = parseHex(widget.config.str('accent')) ?? Ns.amber;
      return Material(
        color: Ns.ground,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.config.titleOr(friendlyName(state, entity)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Ns.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      constraints: const BoxConstraints(
                        minWidth: 56,
                        minHeight: 56,
                      ),
                    ),
                  ],
                ),
                Text(
                  _failed ? '$status · Command failed' : status,
                  style: TextStyle(
                    color: _failed ? Ns.danger : Ns.muted,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (caps.speed) ...[
                        Center(
                          child: Text(
                            '${value.round()}%',
                            style: const TextStyle(
                              color: Ns.text,
                              fontSize: 44,
                              fontFeatures: Ns.tabular,
                            ),
                          ),
                        ),
                        Listener(
                          onPointerDown: (_) => _dragCancelled = false,
                          onPointerCancel: (_) {
                            _dragCancelled = true;
                            setState(() => _drag = null);
                          },
                          child: Slider(
                            value: value,
                            min: 0,
                            max: 100,
                            activeColor: accent,
                            divisions: caps.levels.length - 1,
                            label: '${caps.snap(value)}%',
                            onChanged: enabled
                                ? (v) => setState(
                                    () => _drag = caps.snap(v).toDouble(),
                                  )
                                : null,
                            onChangeEnd: enabled
                                ? (value) {
                                    if (!_dragCancelled) _commit(value);
                                  }
                                : null,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Decrease speed',
                              onPressed: enabled && value > 0
                                  ? () => _commit(
                                      caps.levels
                                          .lastWhere(
                                            (v) => v < value,
                                            orElse: () => 0,
                                          )
                                          .toDouble(),
                                    )
                                  : null,
                              icon: const Icon(Icons.remove),
                              iconSize: 32,
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Increase speed',
                              onPressed: enabled && value < 100
                                  ? () => _commit(
                                      caps.levels
                                          .firstWhere(
                                            (v) => v > value,
                                            orElse: () => 100,
                                          )
                                          .toDouble(),
                                    )
                                  : null,
                              icon: const Icon(Icons.add),
                              iconSize: 32,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (caps.presets.isNotEmpty) ...[
                        const Text(
                          'Preset',
                          style: TextStyle(color: Ns.muted, fontSize: 16),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final mode in caps.presets)
                              ChoiceChip(
                                label: Text(mode),
                                selected: preset == mode,
                                onSelected: enabled && preset != mode
                                    ? (_) => _send('set_preset_mode', {
                                        'preset_mode': mode,
                                      })
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (caps.turnOn || caps.turnOff)
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (caps.turnOn)
                              FilledButton.icon(
                                onPressed: enabled && !state.isOn
                                    ? () => _send('turn_on')
                                    : null,
                                icon: const Icon(Icons.power_settings_new),
                                label: const Text('Turn on'),
                              ),
                            if (caps.turnOff)
                              FilledButton.tonalIcon(
                                onPressed: enabled && state.isOn
                                    ? () => _send('turn_off')
                                    : null,
                                icon: const Icon(Icons.power_settings_new),
                                label: const Text('Turn off'),
                              ),
                          ],
                        ),
                      if (!caps.speed &&
                          caps.presets.isEmpty &&
                          !caps.turnOn &&
                          !caps.turnOff)
                        const Text(
                          'No supported controls',
                          style: TextStyle(color: Ns.muted, fontSize: 16),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
