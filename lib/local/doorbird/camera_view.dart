import 'package:doorbird_intercom/doorbird_intercom.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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
    this.autoLive = false,
    this.openDoor,
    this.incoming,
    this.ringing,
    this.onEnd,
  });
  final IntercomController controller;
  final ValueListenable<int>? incoming;
  final bool Function()? ringing;
  final VoidCallback? onEnd;
  final bool autoLive;
  final Future<bool> Function()? openDoor;
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
  bool _visible = false;
  int _visibilityEpoch = 0;
  bool _doorDialog = false;

  @override
  void initState() {
    super.initState();
    widget.incoming?.addListener(_incoming);
  }

  void _incoming() {
    if (_visible && !widget.controller.inUse) _start();
  }

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

  @override
  void didUpdateWidget(IntercomCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incoming != widget.incoming) {
      oldWidget.incoming?.removeListener(_incoming);
      widget.incoming?.addListener(_incoming);
    }
    if (!oldWidget.autoLive && widget.autoLive) _visible = false;
    _visibility();
  }

  void _visibility() {
    final active = _scope?.active ?? true;
    if (active == _visible) return;
    _visible = active;
    final epoch = ++_visibilityEpoch;
    if (!active) {
      _stop();
    } else if (widget.autoLive || widget.ringing?.call() == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && epoch == _visibilityEpoch && _visible) _start();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  Future<void> _volume() => showControlSheetBuilder(
    context,
    (_) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => ControlSheet(
        title: 'Lautstärke',
        state: 'DoorBird',
        value: widget.controller.volume,
        accent: Ns.violet,
        fromTop: false,
        step: 5,
        actions: const [],
        enabled: widget.controller.inUse,
        onCommit: widget.controller.setVolume,
      ),
    ),
  );

  Future<void> _confirmDoor() async {
    if (_doorDialog || widget.openDoor == null || !_visible) return;
    _doorDialog = true;
    var sent = false;
    var pending = false;
    var status = 'Nur nach Bestätigung';
    var failed = false;
    try {
      await showControlSheetBuilder(
        context,
        (_) => StatefulBuilder(
          builder: (context, update) => ControlSheet(
            title: 'Türsummer',
            state: status,
            stateColor: failed ? Ns.danger : Ns.muted,
            value: 0,
            accent: Ns.mint,
            fromTop: false,
            step: 1,
            showLevel: false,
            body: const Center(
              child: Text(
                'Türsummer an der Eingangstür auslösen?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Ns.text, fontSize: 26),
              ),
            ),
            actions: [
              SheetAction(label: sent ? 'Schließen' : 'Abbrechen', run: () {}),
              SheetAction(
                label: 'Auslösen',
                icon: Icons.lock_open,
                primary: true,
                close: false,
                enabled: !pending && !sent,
                run: () async {
                  if (pending || sent || !mounted || !_visible) return;
                  update(() {
                    pending = true;
                    sent = true;
                    status = 'Wird gesendet …';
                  });
                  var ok = false;
                  try {
                    ok = await widget.openDoor!().timeout(
                      const Duration(seconds: 10),
                    );
                  } catch (_) {
                    /* Never retry a possibly executed door command. */
                  }
                  if (context.mounted) {
                    update(() {
                      pending = false;
                      failed = !ok;
                      status = ok
                          ? 'Befehl gesendet'
                          : 'Ergebnis unklar – Tür prüfen';
                    });
                  }
                },
              ),
            ],
          ),
        ),
      );
    } finally {
      _doorDialog = false;
    }
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
    widget.incoming?.removeListener(_incoming);
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
              _ =>
                c.videoState == IntercomVideoState.live
                    ? 'Live · Hören · Mikrofon aus'
                    : 'Hören · Mikrofon aus',
            };
      final videoNote =
          active && ready && c.videoState != IntercomVideoState.live
          ? c.videoState == IntercomVideoState.reconnecting
                ? 'Video verbindet erneut …'
                : 'Video wird verbunden …'
          : null;
      final hasVideo =
          active &&
          c.videoState == IntercomVideoState.live &&
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
                videoNote == null ? state : '$state\n$videoNote',
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
                      ? () {
                          widget.onEnd?.call();
                          setState(_stop);
                        }
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
                if (widget.openDoor != null) ...[
                  _button(
                    'Lautstärke',
                    Icons.volume_up,
                    ready ? _volume : null,
                  ),
                  const SizedBox(width: SheetMetrics.actionGap),
                  _button('Türsummer', Icons.lock_open, _confirmDoor),
                ] else ...[
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
