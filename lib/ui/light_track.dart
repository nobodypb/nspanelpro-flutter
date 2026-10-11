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
        Widget label(Color color) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${(widget.value * 100).round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  fontFeatures: Ns.tabular,
                ),
              ),
            ),
          ),
        );
        final dark = widget.color.computeLuminance();
        final ink =
            (dark + .05) / (Ns.ground.computeLuminance() + .05) >=
                (Ns.text.computeLuminance() + .05) / (dark + .05)
            ? Ns.ground
            : Ns.text;
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
                  if (widget.percent) ...[
                    ExcludeSemantics(child: label(Ns.text)),
                    ClipRect(
                      clipper: _FillClip(widget.value),
                      child: ExcludeSemantics(child: label(ink)),
                    ),
                  ],
                  Positioned(
                    left: 0,
                    right: 0,
                    top:
                        ((1 - widget.value) * box.maxHeight -
                                (widget.active ? 3 : 2))
                            .clamp(0, box.maxHeight - (widget.active ? 6 : 4)),
                    child: Container(
                      height: widget.active ? 6 : 4,
                      color: Ns.ground,
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: const ColoredBox(color: Ns.text),
                    ),
                  ),
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

class _FillClip extends CustomClipper<Rect> {
  _FillClip(this.value);
  final double value;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, size.height * (1 - value), size.width, size.height);
  @override
  bool shouldReclip(_FillClip oldClipper) => oldClipper.value != value;
}
