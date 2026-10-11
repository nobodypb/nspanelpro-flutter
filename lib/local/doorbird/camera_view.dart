import 'package:doorbird_intercom/doorbird_intercom.dart';
import 'package:flutter/material.dart';

import '../../ui/page_scope.dart';
import '../../ui/sheet.dart';
import '../../ui/theme.dart';

/// A fixed camera viewport and action strip. Only its picture source changes.
class IntercomCameraView extends StatefulWidget {
  const IntercomCameraView({
    super.key,
    required this.controller,
    required this.picture,
    required this.title,
    required this.contain,
    required this.ownsSession,
    required this.onStart,
    required this.onStop,
  });
  final IntercomController controller;
  final Widget picture;
  final String title;
  final bool contain;
  final bool Function(Object) ownsSession;
  final Future<void> Function(Object) onStart;
  final void Function(Object) onStop;

  @override
  State<IntercomCameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<IntercomCameraView> {
  PageScope? _scope;
  Listenable? _pageChanges;
  bool _starting = false;
  bool _profileFailed = false;
  int _intent = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = PageScope.maybeOf(context);
    if (!identical(scope, _scope)) {
      _pageChanges?.removeListener(_visibility);
      _scope = scope;
      _pageChanges = scope?.changes;
      _pageChanges?.addListener(_visibility);
    }
    _visibility();
  }

  void _visibility() {
    if (!(_scope?.active ?? true)) _stop();
  }

  Future<void> _start() async {
    if (_starting || !(_scope?.active ?? true)) return;
    final intent = ++_intent;
    setState(() {
      _starting = true;
      _profileFailed = false;
    });
    try {
      await widget.onStart(this);
    } catch (_) {
      if (mounted && intent == _intent) _profileFailed = true;
    } finally {
      if (mounted && intent == _intent) setState(() => _starting = false);
    }
  }

  void _stop() {
    _intent++;
    _starting = false;
    widget.onStop(this);
  }

  @override
  void dispose() {
    _pageChanges?.removeListener(_visibility);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final owned = widget.ownsSession(this);
      final active = owned && c.inUse;
      final error = _profileFailed
          ? 'configuration'
          : owned
          ? c.error
          : null;
      final speaking = active && c.state == IntercomState.talking;
      final canSpeak =
          active &&
          (c.state == IntercomState.preview || c.state == IntercomState.muted);
      final ready =
          active &&
          {
            IntercomState.preview,
            IntercomState.talking,
            IntercomState.muted,
          }.contains(c.state);
      final state = error != null
          ? intercomMessage(error)
          : _starting || active && c.state == IntercomState.opening
          ? 'Verbinden · Mikrofon aus'
          : !active
          ? 'Standbild · Mikrofon aus'
          : switch (c.state) {
              IntercomState.connecting => 'Gespräch verbinden · Mikrofon aus',
              IntercomState.talking => 'Gespräch · Mikrofon an',
              IntercomState.muted => 'Gespräch · Mikrofon aus',
              IntercomState.ending => 'Beenden · Mikrofon aus',
              _ => 'Live · Hören · Mikrofon aus',
            };
      final hasVideo =
          active &&
          c.texture != null &&
          (c.metrics['video_frames'] as num? ?? 0) > 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              key: const ValueKey('camera-picture'),
              borderRadius: BorderRadius.circular(SheetMetrics.levelRadius),
              child: Semantics(
                container: true,
                label: widget.title,
                image: true,
                child: hasVideo
                    ? ColoredBox(
                        color: Colors.black,
                        child: ClipRect(
                          child: FittedBox(
                            fit: widget.contain ? BoxFit.contain : BoxFit.cover,
                            child: SizedBox(
                              width: 1000 * c.aspectRatio,
                              height: 1000,
                              child: Texture(textureId: c.texture!),
                            ),
                          ),
                        ),
                      )
                    : widget.picture,
              ),
            ),
          ),
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                state,
                key: const ValueKey('camera-status'),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: error == null ? Ns.muted : Ns.danger,
                  fontSize: 14,
                  height: 1.1,
                ),
              ),
            ),
          ),
          SizedBox(
            height: SheetMetrics.actionHeight,
            child: Row(
              children: [
                _button(
                  active || _starting ? 'Beenden' : 'Live',
                  active || _starting ? Icons.stop : Icons.videocam,
                  active || _starting
                      ? () => setState(_stop)
                      : c.inUse
                      ? null
                      : _start,
                  primary: !active,
                ),
                const SizedBox(width: SheetMetrics.actionGap),
                _button(
                  speaking ? 'Stumm' : 'Sprechen',
                  speaking ? Icons.mic_off : Icons.mic,
                  speaking
                      ? c.mute
                      : canSpeak
                      ? c.speak
                      : null,
                ),
                const SizedBox(width: SheetMetrics.actionGap),
                _button(
                  'Leiser',
                  Icons.remove,
                  ready && c.volume > 0
                      ? () => c.setVolume(c.volume - .05)
                      : null,
                  hint: 'Lautstärke ${(c.volume * 100).round()} Prozent',
                ),
                const SizedBox(width: SheetMetrics.actionGap),
                _button(
                  'Lauter',
                  Icons.add,
                  ready && c.volume < 1
                      ? () => c.setVolume(c.volume + .05)
                      : null,
                  hint: 'Lautstärke ${(c.volume * 100).round()} Prozent',
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _button(
    String label,
    IconData icon,
    VoidCallback? run, {
    bool primary = false,
    String? hint,
  }) => Expanded(
    child: SheetButton(
      label: hint == null ? label : '$label · $hint',
      onTap: run,
      color: primary ? Ns.sky : Ns.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: primary ? Ns.ground : Ns.text),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: primary ? Ns.ground : Ns.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
