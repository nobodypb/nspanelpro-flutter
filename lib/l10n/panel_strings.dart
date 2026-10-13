import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

extension PanelStrings on BuildContext {
  // Standalone card previews and existing widget tests mount a MaterialApp
  // without the app's delegates. Use that app's locale for their labels too.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ??
      lookupAppLocalizations(
        Locale(Localizations.localeOf(this).languageCode == 'de' ? 'de' : 'en'),
      );
}

/// Only built-in status words are localized. HA and dashboard supplied text
/// stays exactly as it was configured.
extension PanelStatus on AppLocalizations {
  String defaultLightPreset(String? name) => switch (name) {
    'Low' => lightLow,
    'Mid' => lightMid,
    'Full' => lightFull,
    _ => name ?? '',
  };

  String updateStatus(String value) {
    if (value == 'Updates managed by local develop build') return updatesLocal;
    for (final entry in [
      ('Update check failed: ', updateCheckFailed),
      ('Install failed: ', updateInstallFailed),
      ('Update failed: ', updateFailed),
      ('Downloading ', updateDownloading),
      ('Installing ', updateInstalling),
      ('Installed ', updateInstalled),
      ('Update ', updateAvailable),
    ]) {
      if (value.startsWith(entry.$1)) {
        var detail = value.substring(entry.$1.length);
        if (entry.$1 == 'Installed ') {
          detail = detail.replaceFirst(', restarting', '');
        }
        if (entry.$1 == 'Update ') {
          detail = detail.replaceFirst(' available', '');
        }
        if (entry.$1 == 'Downloading ' || entry.$1 == 'Installing ') {
          detail = detail.replaceFirst('…', '');
        }
        return entry.$2(detail);
      }
    }
    return value;
  }

  String statusWord(String value) => switch (value) {
    'On' => on,
    'Off' => off,
    'Open' => open,
    'Closed' => closed,
    'Stop' => stop,
    'Unavailable' => unavailable,
    'Unknown' => unknown,
    'Loading…' => loading,
    'Playing' => playing,
    'Paused' => paused,
    'Opening' => opening,
    'Closing' => closing,
    'Missing' => missing,
    'Detected' => detected,
    'Clear' => clear,
    'Wet' => wet,
    'Dry' => dryState,
    'Problem' => problem,
    'Nothing playing' => nothingPlaying,
    'Command failed' => commandFailed,
    'No response' => noResponse,
    'on' => on,
    'off' => off,
    'open' => open,
    'closed' => closed,
    'unavailable' => unavailable,
    'unknown' => unknown,
    _ => value,
  };
}
