import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/sheet.dart';
import '../../ui/theme.dart';

import 'package:doorbird_intercom/doorbird_intercom.dart';

/// Media feasibility UI. Door/IR actions are deliberately absent until the
/// real duplex-audio acceptance gate has passed.
Future<void> showIntercomProbe(
  BuildContext context,
  IntercomController controller,
  Map<String, dynamic> profile,
  String title,
) async {
  if (controller.inUse) return;
  unawaited(controller.open(profile));
  try {
    await showControlSheetBuilder(
      context,
      (_) => _IntercomProbe(
        controller: controller,
        profile: profile,
        title: title,
      ),
    );
  } finally {
    await controller.close();
  }
}

class _IntercomProbe extends StatelessWidget {
  const _IntercomProbe({
    required this.controller,
    required this.profile,
    required this.title,
  });
  final IntercomController controller;
  final Map<String, dynamic> profile;
  final String title;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      final canSpeak =
          c.state == IntercomState.preview || c.state == IntercomState.muted;
      final speaking = c.state == IntercomState.talking;
      final state = c.error != null
          ? intercomMessage(c.error)
          : switch (c.state) {
              IntercomState.idle => 'Beendet · Mikrofon aus',
              IntercomState.opening => 'Verbinden · Mikrofon aus',
              IntercomState.preview => 'Live · Hören · Mikrofon aus',
              IntercomState.connecting => 'Gespräch verbinden',
              IntercomState.talking => 'Gespräch · Mikrofon an',
              IntercomState.muted => 'Gespräch · Mikrofon aus',
              IntercomState.ending => 'Beenden',
              IntercomState.error => 'Verbindung fehlgeschlagen',
            };
      return ControlSheet(
        title: title,
        state: state,
        stateColor: c.error == null ? Ns.muted : Ns.danger,
        value: c.volume,
        accent: Ns.sky,
        fromTop: false,
        step: .05,
        showLevel: false,
        body: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(SheetMetrics.levelRadius),
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (c.texture != null)
                        Center(
                          child: AspectRatio(
                            aspectRatio: c.aspectRatio,
                            child: Texture(textureId: c.texture!),
                          ),
                        )
                      else
                        Center(
                          child: Text(
                            c.error != null ? 'Kein Livebild' : 'Verbinden…',
                            style: const TextStyle(color: Ns.text),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ColoredBox(
                          color: Ns.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'Medientest · ${(c.volume * 100).round()} %\nV ${c.metrics['video_frames'] ?? 0} · A ${c.metrics['audio_frames'] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Ns.text,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: SheetMetrics.gap),
            SizedBox(
              width: SheetMetrics.stepWidth,
              child: Column(
                children: [
                  Expanded(
                    child: SheetButton(
                      label: 'Lauter',
                      child: const Icon(Icons.add, size: 34, color: Ns.text),
                      onTap: () => c.setVolume(c.volume + .05),
                    ),
                  ),
                  const SizedBox(height: SheetMetrics.gap),
                  Expanded(
                    child: SheetButton(
                      label: 'Leiser',
                      child: const Icon(Icons.remove, size: 34, color: Ns.text),
                      onTap: () => c.setVolume(c.volume - .05),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SheetAction(
            label: speaking
                ? 'Stumm'
                : c.state == IntercomState.muted
                ? 'Mikrofon an'
                : 'Sprechen',
            primary: !speaking,
            close: false,
            enabled: speaking || canSpeak,
            run: () => speaking ? c.mute() : c.speak(),
          ),
          if (c.state == IntercomState.error || c.state == IntercomState.idle)
            SheetAction(
              label: 'Neu verbinden',
              close: false,
              run: () => c.open(profile),
            ),
          SheetAction(
            label: speaking || c.state == IntercomState.muted
                ? 'Auflegen'
                : 'Schließen',
            run: () {},
          ),
        ],
      );
    },
  );
}
