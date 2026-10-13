import 'package:flutter/material.dart';

import '../l10n/panel_strings.dart';

import '../config/settings.dart';
import '../update/updater.dart';
import '../util/proximity.dart';
import 'theme.dart';

/// Where is Home Assistant, and who are we. Shown once, and again on a
/// rejected token or a two-finger hold on the dashboard.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    this.initial,
    this.message,
    this.updater,
    this.onLanguage,
    required this.onSaved,
  });
  final Settings? initial;
  final String? message;
  final Updater? updater;
  final ValueChanged<Settings> onSaved;
  final ValueChanged<String>? onLanguage;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final _url = TextEditingController(
    text: widget.initial?.url ?? 'http://homeassistant.local:8123',
  );
  late final _dash = TextEditingController(
    text: widget.initial?.dashboard ?? '',
  );
  late final _name = TextEditingController(
    text: widget.initial?.name ?? 'NSPanel',
  );
  late final _mqttHost = TextEditingController(
    text: widget.initial?.mqttHost ?? '',
  );
  late final _mqttUser = TextEditingController(
    text: widget.initial?.mqttUser ?? '',
  );
  final _mqttPass = TextEditingController();
  final _token = TextEditingController();
  String? _err;
  late String _language = widget.initial?.language ?? '';

  @override
  void initState() {
    super.initState();
    _err = widget.message;
  }

  @override
  void dispose() {
    for (final c in [
      _url,
      _dash,
      _name,
      _mqttHost,
      _mqttUser,
      _mqttPass,
      _token,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final token = _token.text.trim().isEmpty
        ? (widget.initial?.token ?? '')
        : _token.text.trim();
    if (_url.text.trim().isEmpty || token.isEmpty) {
      setState(() => _err = context.l10n.urlAndTokenNeeded);
      return;
    }
    final host = _mqttHost.text.trim();
    Map<String, dynamic>? mqtt;
    if (host.isNotEmpty) {
      // host[:port]; an empty password keeps the stored one
      final parts = host.split(':');
      mqtt = {
        'host': parts.first,
        'port': parts.length > 1 ? int.tryParse(parts[1]) ?? 1883 : 1883,
        'username': _mqttUser.text.trim(),
        'password': _mqttPass.text.isEmpty
            ? (widget.initial?.mqttPass ?? '')
            : _mqttPass.text,
      };
    }
    final s = Settings(
      url: _url.text.trim(),
      token: token,
      dashboard: _dash.text.trim(),
      cachedConfig: widget.initial?.cachedConfig,
      screensaver: widget.initial?.screensaver,
      mqtt: mqtt,
      name: _name.text.trim().isEmpty ? 'NSPanel' : _name.text.trim(),
      ttsEngine: widget.initial?.ttsEngine ?? '',
      feedback: widget.initial?.feedback,
      overrides: widget.initial?.overrides,
      brightness: widget.initial?.brightness,
      language: _language,
    );
    s.save().then((_) => widget.onSaved(s));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final field = InputDecoration(
      filled: true,
      fillColor: Ns.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(12),
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              l.connectTitle,
              style: TextStyle(
                color: Ns.text,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.connectHelp,
              style: TextStyle(color: Ns.muted, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              l.language,
              style: const TextStyle(color: Ns.muted, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: field,
              dropdownColor: Ns.surface,
              items: [
                DropdownMenuItem(value: '', child: Text(l.languageSystem)),
                DropdownMenuItem(value: 'de', child: Text(l.languageGerman)),
                DropdownMenuItem(value: 'en', child: Text(l.languageEnglish)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _language = value);
                widget.onLanguage?.call(value);
              },
            ),
            const SizedBox(height: 16),
            Text(
              l.homeAssistantUrl,
              style: TextStyle(color: Ns.muted, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: field,
            ),
            const SizedBox(height: 12),
            Text(
              widget.initial == null ? l.accessToken : l.newAccessToken,
              style: const TextStyle(color: Ns.muted, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _token,
              maxLines: 3,
              decoration: field,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              l.dashboardPath,
              style: TextStyle(color: Ns.muted, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _dash,
              decoration: field.copyWith(hintText: l.dashboardHint),
            ),
            const SizedBox(height: 16),
            Text(l.deviceName, style: TextStyle(color: Ns.muted, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              decoration: field.copyWith(hintText: l.deviceNameHint),
            ),
            const SizedBox(height: 12),
            Text(l.mqttBroker, style: TextStyle(color: Ns.muted, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _mqttHost,
              keyboardType: TextInputType.url,
              decoration: field.copyWith(hintText: l.mqttBrokerHint),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mqttUser,
                    decoration: field.copyWith(hintText: l.mqttUser),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _mqttPass,
                    obscureText: true,
                    decoration: field.copyWith(
                      hintText: widget.initial?.mqttPass != null
                          ? l.mqttPasswordKept
                          : l.mqttPassword,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 18,
              child: Text(
                _err ?? '',
                style: const TextStyle(color: Ns.danger, fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Ns.amber,
                  foregroundColor: Ns.ground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _save,
                child: Text(l.connect),
              ),
            ),
            const SizedBox(height: 18),
            // The proximity sensor, live, so you can watch what it does when
            // you walk up and pick proximity_delta or an absolute threshold.
            StreamBuilder<double>(
              stream: Proximity.stream,
              builder: (_, snap) => Text(
                snap.hasError
                    ? l.noProximitySensor
                    : l.proximityNow(snap.data?.toStringAsFixed(0) ?? '…'),
                style: const TextStyle(
                  color: Ns.muted,
                  fontSize: 13,
                  fontFeatures: Ns.tabular,
                ),
              ),
            ),
            if (widget.updater != null) ...[
              const SizedBox(height: 10),
              _UpdateRow(updater: widget.updater!),
            ],
          ],
        ),
      ),
    );
  }
}

/// The installed version, what GitHub has, and a button when they differ.
/// The same install HA's update entity triggers, reachable from the panel.
class _UpdateRow extends StatelessWidget {
  const _UpdateRow({required this.updater});
  final Updater updater;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      updater.latest,
      updater.progress,
      updater.status,
    ]),
    builder: (context, _) {
      final l = context.l10n;
      final busy = updater.progress.value != null;
      final status = l.updateStatus(updater.status.value);
      return Row(
        children: [
          Expanded(
            child: Text(
              'App ${updater.installed}${status.isEmpty ? '' : ' · $status'}'
              '${busy ? ' ${updater.progress.value}%' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Ns.muted,
                fontSize: 13,
                fontFeatures: Ns.tabular,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (updater.updateAvailable && !busy)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Ns.mint,
                foregroundColor: Ns.ground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => updater.install(),
              child: Text(l.updateTo(updater.latest.value!.version)),
            )
          else if (!busy)
            TextButton(
              onPressed: () => updater.check(),
              child: Text(
                l.checkUpdates,
                style: TextStyle(color: Ns.muted, fontSize: 13),
              ),
            ),
        ],
      );
    },
  );
}
