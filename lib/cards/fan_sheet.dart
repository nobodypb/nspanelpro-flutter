import 'dart:async';

import 'package:flutter/material.dart';

import '../config/dashboard.dart';
import '../ha/states.dart';
import '../ui/sheet.dart';
import '../ui/theme.dart';
import '../util/color.dart';
import 'env.dart';
import 'fan_capabilities.dart';

/// The same control surface as lights and covers. The generic sheet extensions
/// are included on this feature branch, so no other feature merge is required.
Future<void> showFanSheet(
  BuildContext context,
  CardConfig config,
  PanelEnv env,
) =>
    showControlSheetBuilder(context, (_) => FanSheet(config: config, env: env));

class FanSheet extends StatefulWidget {
  const FanSheet({super.key, required this.config, required this.env});
  final CardConfig config;
  final PanelEnv env;

  @override
  State<FanSheet> createState() => _FanSheetState();
}

class _FanSheetState extends State<FanSheet> {
  String get entity => widget.config.str('entity') ?? '';
  bool _busy = false;
  bool _failed = false;
  bool _choosingPreset = false;
  double? _echo;
  Timer? _echoTimer;

  @override
  void dispose() {
    _echoTimer?.cancel();
    super.dispose();
  }

  Future<bool> _send(
    String service, [
    Map<String, dynamic> data = const {},
  ]) async {
    final state = widget.env.states.get(entity);
    if (_busy || state == null || state.isBroken || !widget.env.conn.isOnline) {
      return false;
    }
    final caps = FanCapabilities(state);
    final allowed = switch (service) {
      'turn_on' => caps.turnOn,
      'turn_off' => caps.turnOff,
      'set_percentage' => caps.speed,
      'set_preset_mode' => caps.presets.contains(data['preset_mode']),
      _ => false,
    };
    if (!allowed) return false;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await widget.env.conn.callService('fan', service, {
      'entity_id': entity,
      ...data,
    });
    if (!mounted) return ok;
    setState(() {
      _busy = false;
      _failed = !ok;
    });
    return ok;
  }

  Future<void> _commit(double value) async {
    final caps = FanCapabilities(widget.env.states.get(entity));
    final pct = caps.snap(value * 100);
    _echoTimer?.cancel();
    setState(() => _echo = pct / 100);
    _echoTimer = Timer(
      Duration(
        milliseconds: widget.config.intOr('echo_ms', 1500).clamp(0, 10000),
      ),
      () {
        if (mounted) setState(() => _echo = null);
      },
    );
    if (!await _send('set_percentage', {'percentage': pct}) &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      _echoTimer?.cancel();
      setState(() => _echo = null);
    }
  }

  Future<void> _action(
    String service, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (await _send(service, data) &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
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
      final raw = state?.attributes['percentage'];
      final actual = raw is num && raw.isFinite
          ? raw.toDouble().clamp(0.0, 100.0) / 100
          : 0.0;
      final value = available && caps.speed ? _echo ?? actual : actual;
      final preset = state?.attr<String>('preset_mode');
      final on = state?.isOn ?? false;
      final status = !available
          ? 'Unavailable'
          : on
          ? 'On'
          : 'Off';
      final accent = parseHex(widget.config.str('accent')) ?? Ns.amber;
      final powerOn = caps.turnOn && (!on || !caps.turnOff);
      final chooser = _choosingPreset && caps.presets.isNotEmpty;
      final statusText = _failed
          ? '$status · Command failed'
          : preset != null
          ? '$status · $preset'
          : status;
      final actions = <SheetAction>[
        if (chooser)
          SheetAction(
            label: 'Back',
            icon: Icons.arrow_back,
            close: false,
            run: () => setState(() => _choosingPreset = false),
          )
        else ...[
          if (caps.presets.length > 3)
            SheetAction(
              label: 'Presets',
              icon: Icons.tune,
              close: false,
              run: () => setState(() => _choosingPreset = true),
            )
          else
            for (final mode in caps.presets)
              SheetAction(
                label: mode,
                icon: mode == preset ? Icons.check : Icons.tune,
                selected: mode == preset,
                enabled: available && !_busy && mode != preset,
                close: false,
                run: () => _action('set_preset_mode', {'preset_mode': mode}),
              ),
          if (caps.turnOn || caps.turnOff)
            SheetAction(
              label: powerOn ? 'Turn on' : 'Turn off',
              icon: Icons.power_settings_new,
              primary: true,
              close: false,
              enabled: available && !_busy && (powerOn != on),
              run: () => _action(powerOn ? 'turn_on' : 'turn_off'),
            ),
        ],
      ];
      return ControlSheet(
        title: chooser
            ? 'Presets'
            : widget.config.titleOr(friendlyName(state, entity)),
        state: statusText,
        stateColor: _failed ? Ns.danger : Ns.muted,
        value: value,
        accent: accent,
        fromTop: false,
        showLevel: caps.speed,
        enabled: available && !_busy,
        step: 100 / (caps.levels.length - 1),
        snapValue: (v) => caps.snap(v * 100) / 100,
        stepValue: (v, direction) =>
            (direction > 0
                ? caps.levels.firstWhere(
                    (level) => level > (v * 100).round(),
                    orElse: () => 100,
                  )
                : caps.levels.lastWhere(
                    (level) => level < (v * 100).round(),
                    orElse: () => 0,
                  )) /
            100,
        onCommit: _commit,
        actions: actions,
        body: chooser
            ? GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: SheetMetrics.actionHeight,
                  mainAxisSpacing: SheetMetrics.actionGap,
                  crossAxisSpacing: SheetMetrics.actionGap,
                ),
                itemCount: caps.presets.length,
                itemBuilder: (_, index) {
                  final mode = caps.presets[index];
                  return SheetButton(
                    label: mode,
                    color: mode == preset
                        ? accent.withValues(alpha: .16)
                        : Ns.surface,
                    onTap: available && !_busy && mode != preset
                        ? () =>
                              _action('set_preset_mode', {'preset_mode': mode})
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        mode,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: mode == preset ? accent : Ns.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              )
            : null,
      );
    },
  );
}
