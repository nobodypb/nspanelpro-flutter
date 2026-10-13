import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../config/dashboard.dart';
import '../ha/states.dart';
import '../ui/page_scope.dart';
import '../ui/sheet.dart';
import '../ui/theme.dart';
import '../util/color.dart';
import '../util/icons.dart';
import '../util/usage_candidates.dart';
import '../util/usage_history.dart';
import 'env.dart';
import 'fan_capabilities.dart';
import 'fan_sheet.dart';
import 'light_controls.dart';
import 'light_sheet.dart';
import 'switch_sheet.dart';

class FrequentCard extends StatefulWidget {
  const FrequentCard({super.key, required this.config, required this.env});
  final CardConfig config;
  final PanelEnv env;

  @override
  State<FrequentCard> createState() => _FrequentCardState();
}

class _FrequentCardState extends State<FrequentCard> {
  CardConfig get config => widget.config;
  PanelEnv get env => widget.env;
  final Map<String, ({bool on, DateTime until, int revision})> _powerEcho = {};
  final List<Timer> _timers = [];

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  int get count {
    final raw = config['count'];
    return raw is int ? raw.clamp(1, capacity) : 3;
  }

  int get height {
    final raw = config['height'];
    return raw is num && raw >= 162 ? 162 : 126;
  }

  int get capacity => height == 162 ? 6 : 3;

  Set<String> get domains => config
      .listOr('entity_domains')
      .whereType<String>()
      .where(UsageHistory.domains.contains)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final scope = PageScope.maybeOf(context);
    final usage = env.usage;
    if (scope == null || usage == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge([usage, scope.changes]),
      builder: (context, _) {
        final choices = recommendedCandidates(
          candidates: env.usageCandidates?.call() ?? const [],
          counts: usage.counts(),
          recommendationPage: scope.index,
          count: count,
          domains: domains,
        );
        return Container(
          height: height.toDouble(),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            color: Ns.surface,
            borderRadius: BorderRadius.circular(Ns.radius),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      config.titleOr('Häufig genutzt'),
                      style: const TextStyle(
                        color: Ns.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${choices.length}/$count',
                    style: const TextStyle(color: Ns.muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: choices.isEmpty
                    ? const Center(
                        child: Text(
                          'Noch keine Nutzung',
                          style: TextStyle(color: Ns.muted, fontSize: 14),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final choice in choices)
                                SizedBox(
                                  width: (constraints.maxWidth - 16) / 3,
                                  height: 58,
                                  child: _tile(context, choice, scope.active),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, UsageCandidate candidate, bool active) {
    return ValueListenableBuilder<HaState?>(
      valueListenable: env.states.listen(candidate.entity),
      builder: (context, state, _) {
        final unavailable = state == null || state.isBroken;
        final item = candidate.item;
        final title =
            item?.str('name') ??
            candidate.config.titleOr(friendlyName(state, candidate.entity));
        final accent =
            parseHex(candidate.config.str('accent')) ??
            _accent(candidate.domain);
        final echo = _powerEcho[candidate.entity];
        final on = echo != null && DateTime.now().isBefore(echo.until)
            ? echo.on
            : (state?.isOn ?? false);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: !active || unavailable
              ? null
              : () => _act(context, candidate, state, false),
          onLongPress: !active || unavailable
              ? null
              : () => _act(context, candidate, state, true),
          child: Opacity(
            opacity: unavailable ? .45 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: on ? accent.withValues(alpha: .16) : Ns.surface2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    mdi(
                      item?.str('icon') ??
                          candidate.config.str('icon') ??
                          state?.attr<String>('icon'),
                      _icon(candidate.domain),
                    ),
                    size: 25,
                    color: on ? accent : Ns.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Ns.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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

  Color _accent(String domain) => switch (domain) {
    'cover' => Ns.sky,
    'climate' => Ns.ember,
    'media_player' => Ns.violet,
    _ => Ns.amber,
  };

  IconData _icon(String domain) => switch (domain) {
    'cover' => MdiIcons.blinds,
    'climate' => MdiIcons.thermostat,
    'media_player' => MdiIcons.music,
    'fan' => MdiIcons.fan,
    'switch' || 'input_boolean' => MdiIcons.toggleSwitchVariant,
    _ => MdiIcons.lightbulbOutline,
  };

  void _act(BuildContext context, UsageCandidate c, HaState state, bool hold) {
    final cfg = c.config, item = c.item;
    final swap =
        item?.boolOr(
          'swap_press_actions',
          cfg.boolOr('swap_press_actions', false),
        ) ??
        cfg.boolOr('swap_press_actions', false);
    switch (c.domain) {
      case 'light':
        if (c.card == 'nspanel-switch-card') {
          if (hold != swap) {
            _switchDetails(context, c);
          } else {
            _switchPower(context, c, state);
          }
        } else if (hold == swap) {
          LightControls(cfg, env).call('toggle');
        } else if (cfg.str('long_press') != 'none') {
          showControlSheetBuilder(
            context,
            (_) => LightSheet(config: cfg, env: env),
          );
        }
      case 'switch' || 'input_boolean' || 'fan':
        if (hold != swap) {
          _switchDetails(context, c);
        } else {
          _switchPower(context, c, state);
        }
      case 'cover':
        if (hold) {
          if (cfg.str('long_press') != 'none') _coverDetails(context, c, state);
        } else {
          env.conn.callService(
            'cover',
            const {'opening', 'closing'}.contains(state.state)
                ? 'stop_cover'
                : 'toggle',
            {'entity_id': c.entity},
          );
        }
      case 'climate':
        _climateDetails(context, c, state);
      case 'media_player':
        if (hold) {
          if (cfg.str('long_press') != 'none') _mediaDetails(context, c, state);
        } else {
          env.conn.callService('media_player', 'media_play_pause', {
            'entity_id': c.entity,
          });
        }
    }
  }

  void _switchPower(BuildContext context, UsageCandidate c, HaState state) {
    if (c.domain == 'fan') {
      final caps = FanCapabilities(state);
      if (state.isOn ? !caps.turnOff : !caps.turnOn) {
        _switchDetails(context, c);
        return;
      }
      env.conn.callService('fan', state.isOn ? 'turn_off' : 'turn_on', {
        'entity_id': c.entity,
      });
    } else {
      final echo = _powerEcho[c.entity];
      final wasOn = echo != null && DateTime.now().isBefore(echo.until)
          ? echo.on
          : state.isOn;
      final next = !wasOn;
      final revision = (echo?.revision ?? 0) + 1;
      final duration = c.config.intOr('echo_ms', 1500);
      setState(
        () => _powerEcho[c.entity] = (
          on: next,
          until: DateTime.now().add(Duration(milliseconds: duration)),
          revision: revision,
        ),
      );
      _timers.add(
        Timer(Duration(milliseconds: duration + 20), () {
          if (mounted) setState(() {});
        }),
      );
      env.conn
          .callService('homeassistant', next ? 'turn_on' : 'turn_off', {
            'entity_id': c.entity,
          })
          .then((ok) {
            if (!ok && mounted && _powerEcho[c.entity]?.revision == revision) {
              setState(() => _powerEcho.remove(c.entity));
            }
          });
    }
  }

  void _switchDetails(BuildContext context, UsageCandidate c) {
    if (!c.config.boolOr('more_info', true)) return;
    final item = c.item ?? c.config;
    final entity = item.str('detail_entity') ?? c.entity;
    final config = <String, dynamic>{
      'entity': entity,
      'name': item.str('detail_name') ?? item.str('name'),
      'accent': c.config['accent'],
      'step_target': item['step_target'] ?? c.config['step_target'],
      'step': item['step'] ?? c.config['step'],
      'effect_favorites':
          item['effect_favorites'] ?? c.config['effect_favorites'],
    };
    if (entity.startsWith('fan.')) {
      showFanSheet(context, config, env);
    } else {
      showControlSheetBuilder(
        context,
        (_) => entity.startsWith('light.')
            ? LightSheet(config: config, env: env)
            : SwitchSheet(config: config, env: env),
      );
    }
  }

  void _coverDetails(BuildContext context, UsageCandidate c, HaState s) {
    final value =
        ((s.numAttr('current_position') ?? (s.state == 'open' ? 100 : 0)) / 100)
            .clamp(0.0, 1.0);
    Future<bool> call(String service, [Map<String, dynamic>? data]) => env.conn
        .callService('cover', service, {'entity_id': c.entity, ...?data});
    showControlSheet(
      context,
      title: c.config.titleOr(friendlyName(s, c.entity)),
      state: s.state,
      value: value,
      fromTop: true,
      accent: parseHex(c.config.str('accent')) ?? Ns.sky,
      step: c.config.numOr('step', 5),
      actions: [
        SheetAction(
          label: 'Open',
          icon: MdiIcons.arrowUp,
          run: () => call('open_cover'),
        ),
        SheetAction(
          label: 'Stop',
          icon: MdiIcons.stop,
          primary: true,
          close: false,
          run: () => call('stop_cover'),
        ),
        SheetAction(
          label: 'Close',
          icon: MdiIcons.arrowDown,
          run: () => call('close_cover'),
        ),
      ],
      onCommit: (v) => s.supports(4)
          ? call('set_cover_position', {'position': (v * 100).round()})
          : call(v > .5 ? 'open_cover' : 'close_cover'),
    );
  }

  void _climateDetails(BuildContext context, UsageCandidate c, HaState s) {
    final min = c.config.numOr('min', s.numAttr('min_temp') ?? 7);
    final max = c.config.numOr('max', s.numAttr('max_temp') ?? 35);
    final range = max > min ? max - min : 1.0;
    final step = c.config.numOr('step', .5);
    final target = s.numAttr('temperature') ?? min;
    showControlSheet(
      context,
      title: c.config.titleOr(friendlyName(s, c.entity)),
      state: s.state,
      value: ((target - min) / range).clamp(0.0, 1.0),
      accent: parseHex(c.config.str('accent')) ?? Ns.ember,
      step: step / range * 100,
      actions: [
        for (final mode
            in (s.attributes['hvac_modes'] as List? ?? const [])
                .whereType<String>()
                .where(
                  const {
                    'off',
                    'heat',
                    'cool',
                    'heat_cool',
                    'auto',
                    'dry',
                    'fan_only',
                  }.contains,
                )
                .take(4))
          SheetAction(
            label: mode,
            icon: MdiIcons.thermostat,
            primary: s.state == mode,
            run: () => env.conn.callService('climate', 'set_hvac_mode', {
              'entity_id': c.entity,
              'hvac_mode': mode,
            }),
          ),
      ],
      onCommit: (v) => env.conn.callService('climate', 'set_temperature', {
        'entity_id': c.entity,
        'temperature': (((min + v * range) / step).round() * step).clamp(
          min,
          max,
        ),
      }),
    );
  }

  void _mediaDetails(BuildContext context, UsageCandidate c, HaState s) {
    final value = (s.numAttr('volume_level') ?? 0).clamp(0.0, 1.0);
    Future<bool> call(String service, [Map<String, dynamic>? data]) =>
        env.conn.callService('media_player', service, {
          'entity_id': c.entity,
          ...?data,
        });
    showControlSheet(
      context,
      title: c.config.titleOr(friendlyName(s, c.entity)),
      state: s.state,
      value: value,
      accent: parseHex(c.config.str('accent')) ?? Ns.violet,
      step: c.config.numOr('step', 5),
      actions: [
        if (s.supports(16))
          SheetAction(
            label: 'Previous',
            icon: MdiIcons.skipPrevious,
            close: false,
            run: () => call('media_previous_track'),
          ),
        SheetAction(
          label: s.state == 'playing' ? 'Pause' : 'Play',
          icon: s.state == 'playing' ? MdiIcons.pause : MdiIcons.play,
          primary: true,
          close: false,
          run: () => call('media_play_pause'),
        ),
        if (s.supports(32))
          SheetAction(
            label: 'Next',
            icon: MdiIcons.skipNext,
            close: false,
            run: () => call('media_next_track'),
          ),
        if (s.supports(4096))
          SheetAction(
            label: 'Stop',
            icon: MdiIcons.stop,
            run: () => call('media_stop'),
          )
        else if (s.supports(256))
          SheetAction(
            label: 'Off',
            icon: MdiIcons.power,
            run: () => call('turn_off'),
          ),
      ],
      onCommit: s.supports(4)
          ? (v) => call('volume_set', {'volume_level': (v * 100).round() / 100})
          : null,
    );
  }
}
