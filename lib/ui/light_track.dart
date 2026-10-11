import 'package:flutter/material.dart';

import 'sheet.dart';
import 'theme.dart';

/// A whole-column absolute slider; labels are semantic, never painted.
class LightTrack extends StatefulWidget {
  const LightTrack({
    super.key,
    required this.label,
    required this.valueText,
    required this.increasedText,
    required this.decreasedText,
    required this.value,
    required this.color,
    this.gradient,
    this.percent = false,
    this.active = false,
    this.enabled = true,
    this.dimWhenDisabled = true,
    required this.onInput,
    required this.onCommit,
    required this.onCancel,
    required this.onIncrease,
    required this.onDecrease,
  });
  final String label, valueText, increasedText, decreasedText;
  final double value;
  final Color color;
  final List<Color>? gradient;
  final bool percent, active, enabled, dimWhenDisabled;
  final ValueChanged<double> onInput, onCommit;
  final VoidCallback onCancel, onIncrease, onDecrease;
  @override
  State<LightTrack> createState() => _LightTrackState();
}

class _LightTrackState extends State<LightTrack> {
  bool _dragging = false;
  double _value = 0;
  @override
  void didUpdateWidget(LightTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _dragging = false;
  }

  void cancel() {
    _dragging = false;
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    value: widget.valueText,
    increasedValue: widget.increasedText,
    decreasedValue: widget.decreasedText,
    enabled: widget.enabled,
    slider: true,
    onIncrease: widget.enabled ? widget.onIncrease : null,
    onDecrease: widget.enabled ? widget.onDecrease : null,
    child: LayoutBuilder(
      builder: (_, box) {
        double at(double y) => (1 - y / box.maxHeight).clamp(0, 1);
        Widget label() => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${(widget.value * 100).round()}'),
                    const TextSpan(
                      text: '%',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                style: TextStyle(
                  color: Ns.text,
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  fontFeatures: Ns.tabular,
                  shadows: [
                    ...Ns.shadow,
                    // Keep card-like light text readable over bright colours.
                    for (final offset in const [
                      Offset(-1, 0),
                      Offset(1, 0),
                      Offset(0, -1),
                      Offset(0, 1),
                    ])
                      Shadow(offset: offset, color: Ns.ground),
                  ],
                ),
              ),
            ),
          ),
        );
        // Match the card's plain level line. Put it just above the fill;
        // gradients and a completely filled track may need contrasting ink.
        Color background = widget.value == 1 ? widget.color : Ns.surface;
        if (widget.gradient case final colors?) {
          final position = widget.value * (colors.length - 1);
          final index = position.floor().clamp(0, colors.length - 2);
          background = Color.lerp(
            colors[index],
            colors[index + 1],
            position - index,
          )!;
        }
        double contrast(Color a, Color b) {
          final x = a.computeLuminance(), y = b.computeLuminance();
          return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
        }

        final lineColor = contrast(widget.color, background) >= 3
            ? widget.color
            : contrast(Ns.ground, background) > contrast(Ns.text, background)
            ? Ns.ground
            : Ns.text;
        final lineHeight = widget.active ? 5.0 : 3.0;
        return Listener(
          onPointerCancel: (_) => cancel(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.enabled
                ? (d) => widget.onCommit(at(d.localPosition.dy))
                : null,
            onVerticalDragStart: widget.enabled
                ? (d) {
                    _dragging = true;
                    _value = at(d.localPosition.dy);
                    widget.onInput(_value);
                  }
                : null,
            onVerticalDragUpdate: widget.enabled
                ? (d) {
                    if (!_dragging) return;
                    _value = at(d.localPosition.dy);
                    widget.onInput(_value);
                  }
                : null,
            onVerticalDragEnd: widget.enabled
                ? (_) {
                    if (!_dragging) return;
                    _dragging = false;
                    widget.onCommit(_value);
                  }
                : null,
            onVerticalDragCancel: cancel,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SheetMetrics.levelRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Ns.surface),
                  if (widget.gradient != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: widget.gradient!,
                        ),
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: widget.value,
                        widthFactor: 1,
                        child: ColoredBox(color: widget.color),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: ((1 - widget.value) * box.maxHeight - lineHeight)
                        .clamp(0, box.maxHeight - lineHeight),
                    child: Container(height: lineHeight, color: lineColor),
                  ),
                  if (widget.percent) ExcludeSemantics(child: label()),
                  if (!widget.enabled && widget.dimWhenDisabled)
                    const ColoredBox(color: Color(0x550B0D10)),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
