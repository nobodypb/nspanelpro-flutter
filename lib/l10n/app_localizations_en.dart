// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get connectTitle => 'Connect to Home Assistant';

  @override
  String get connectHelp =>
      'Create a long-lived access token under your profile, Security, at the bottom. It is stored on this panel only.';

  @override
  String get homeAssistantUrl => 'Home Assistant URL';

  @override
  String get accessToken => 'Long-lived access token';

  @override
  String get newAccessToken =>
      'New token (leave empty to keep the current one)';

  @override
  String get dashboardPath => 'Dashboard (url path, empty = default)';

  @override
  String get dashboardHint => 'e.g. nspanel';

  @override
  String get deviceName => 'Device name in Home Assistant';

  @override
  String get deviceNameHint => 'NSPanel Dining';

  @override
  String get mqttBroker => 'MQTT broker (host or host:port, empty = no device)';

  @override
  String get mqttBrokerHint => 'e.g. 10.0.0.2 or homeassistant.local:1883';

  @override
  String get mqttUser => 'MQTT user';

  @override
  String get mqttPassword => 'MQTT password';

  @override
  String get mqttPasswordKept => 'password (kept)';

  @override
  String get connect => 'Connect';

  @override
  String get urlAndTokenNeeded => 'Both the URL and a token are needed.';

  @override
  String get noProximitySensor => 'No proximity sensor on this device.';

  @override
  String proximityNow(String value) {
    return 'Proximity sensor now: $value';
  }

  @override
  String updateTo(String version) {
    return 'Update to $version';
  }

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String get close => 'Close';

  @override
  String get increase => 'Increase';

  @override
  String get decrease => 'Decrease';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get open => 'Open';

  @override
  String get closed => 'Closed';

  @override
  String get stop => 'Stop';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get unknown => 'Unknown';

  @override
  String get loading => 'Loading…';

  @override
  String get offline => 'OFFLINE';

  @override
  String get turnOn => 'Turn on';

  @override
  String get turnOff => 'Turn off';

  @override
  String get commandFailed => 'Command failed';

  @override
  String get back => 'Back';

  @override
  String get presets => 'Presets';

  @override
  String get colour => 'Colour';

  @override
  String get white => 'White';

  @override
  String get effects => 'Effects';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get playing => 'Playing';

  @override
  String get paused => 'Paused';

  @override
  String get nothingPlaying => 'Nothing playing';

  @override
  String pausedDetail(String detail) {
    return 'Paused · $detail';
  }

  @override
  String onPercent(String percent) {
    return 'On · $percent%';
  }

  @override
  String get offLastValues => 'Off · last values';

  @override
  String get opening => 'Opening';

  @override
  String get closing => 'Closing';

  @override
  String percentOpen(String percent) {
    return '$percent% open';
  }

  @override
  String get coverHalf => 'Half';

  @override
  String get coverShut => 'Shut';

  @override
  String get heat => 'Heat';

  @override
  String get cool => 'Cool';

  @override
  String get auto => 'Auto';

  @override
  String get dryMode => 'Dry';

  @override
  String get fan => 'Fan';

  @override
  String get idle => 'Idle';

  @override
  String get eco => 'Eco';

  @override
  String get day => 'Day';

  @override
  String get warm => 'Warm';

  @override
  String nowTemperature(String temperature, String mode) {
    return 'Now $temperature° · $mode';
  }

  @override
  String get missing => 'Missing';

  @override
  String get detected => 'Detected';

  @override
  String get clear => 'Clear';

  @override
  String get wet => 'Wet';

  @override
  String get dryState => 'Dry';

  @override
  String get problem => 'Problem';

  @override
  String get allClear => 'All clear';

  @override
  String get run => 'Run';

  @override
  String get tapAgain => 'Tap again';

  @override
  String get frequentlyUsed => 'Frequently used';

  @override
  String get noUsageYet => 'No usage yet';

  @override
  String get noResponse => 'No response';

  @override
  String get brightness => 'Brightness';

  @override
  String get temperature => 'Temperature';

  @override
  String get hue => 'Hue';

  @override
  String get saturation => 'Saturation';

  @override
  String increaseChannel(String channel) {
    return 'Increase $channel';
  }

  @override
  String decreaseChannel(String channel) {
    return 'Decrease $channel';
  }

  @override
  String degrees(String value) {
    return '$value degrees';
  }

  @override
  String kelvin(String value) {
    return '$value kelvin';
  }

  @override
  String get connecting => 'Connecting…';

  @override
  String get tokenRejected => 'That token was rejected. Paste a new one.';

  @override
  String noSupportedCards(String path) {
    return 'The dashboard \"$path\" has no cards this app can draw. It needs custom:nspanel-* cards.';
  }

  @override
  String get defaultDashboard => 'default';

  @override
  String get defaultDashboardName => 'the default dashboard';

  @override
  String dashboardLoadFailed(String name, String error) {
    return 'Could not load $name: $error';
  }

  @override
  String dashboardAutoGenerated(String path) {
    return 'Dashboard \"$path\" exists but has no saved config yet. In Home Assistant open it, then ⋮ → Edit dashboard → Take control, add the nspanel cards and save. This panel reloads on its own.';
  }

  @override
  String dashboardKnown(String name, String error, String paths) {
    return 'Could not load $name: $error\n\nDashboards on this Home Assistant:\n$paths\n\nHold two fingers to change it.';
  }

  @override
  String get defaultDashboardEntry => '(empty) for the default dashboard';

  @override
  String get weatherSunny => 'Sunny';

  @override
  String get weatherClear => 'Clear';

  @override
  String get weatherCloudy => 'Cloudy';

  @override
  String get weatherFog => 'Fog';

  @override
  String get weatherHail => 'Hail';

  @override
  String get weatherLightning => 'Thunderstorm';

  @override
  String get weatherThunderRain => 'Thunder, rain';

  @override
  String get weatherPartlyCloudy => 'Partly cloudy';

  @override
  String get weatherPouring => 'Heavy rain';

  @override
  String get weatherRainy => 'Rainy';

  @override
  String get weatherSnowy => 'Snowy';

  @override
  String get weatherSleet => 'Sleet';

  @override
  String get weatherWindy => 'Windy';

  @override
  String get weatherSevere => 'Severe';

  @override
  String byPerson(String name, String person) {
    return '$name · by $person';
  }

  @override
  String get alarmHome => 'Home';

  @override
  String get alarmAway => 'Away';

  @override
  String get alarmNight => 'Night';

  @override
  String get alarmBypass => 'Bypass';

  @override
  String get alarmVacation => 'Vacation';

  @override
  String get alarmDisarmed => 'Disarmed';

  @override
  String get alarmArmedHome => 'Armed home';

  @override
  String get alarmArmedAway => 'Armed away';

  @override
  String get alarmArmedNight => 'Armed night';

  @override
  String get alarmArmedVacation => 'Armed vacation';

  @override
  String get alarmArmedBypass => 'Armed (bypass)';

  @override
  String get alarmArming => 'Arming…';

  @override
  String get alarmDisarming => 'Disarming…';

  @override
  String get alarmPending => 'Pending…';

  @override
  String get alarmTriggered => 'TRIGGERED';

  @override
  String get alarmDisarm => 'Disarm';

  @override
  String alarmArmMode(String mode) {
    return 'Arm $mode';
  }

  @override
  String get doorVolume => 'Volume';

  @override
  String get doorBuzzer => 'Door buzzer';

  @override
  String get doorConfirmRequired => 'Only after confirmation';

  @override
  String get doorConfirmPrompt => 'Activate the front door buzzer?';

  @override
  String get doorCancel => 'Cancel';

  @override
  String get doorSend => 'Activate';

  @override
  String get doorSending => 'Sending…';

  @override
  String get doorSent => 'Command sent';

  @override
  String get doorUncertain => 'Outcome unclear – check the door';

  @override
  String get doorConnecting => 'Connecting · Mic off';

  @override
  String get doorStill => 'Still image · Mic off';

  @override
  String get doorCallConnecting => 'Connecting call · Mic off';

  @override
  String get doorTalking => 'Call · Mic on';

  @override
  String get doorMuted => 'Call · Mic off';

  @override
  String get doorEnding => 'Ending · Mic off';

  @override
  String get doorLiveListen => 'Live · Listen · Mic off';

  @override
  String get doorListen => 'Listen · Mic off';

  @override
  String get doorVideoReconnecting => 'Reconnecting video…';

  @override
  String get doorVideoConnecting => 'Connecting video…';

  @override
  String get doorEnd => 'End';

  @override
  String get doorLive => 'Live';

  @override
  String get doorMute => 'Mute';

  @override
  String get doorSpeak => 'Speak';

  @override
  String get doorQuieter => 'Quieter';

  @override
  String get doorLouder => 'Louder';

  @override
  String doorVolumePercent(String percent) {
    return 'Volume $percent percent';
  }

  @override
  String get doorErrPermission => 'Microphone or DoorBird access denied';

  @override
  String get doorErrAuthentication => 'Check DoorBird credentials';

  @override
  String get doorErrCertificate => 'Check DoorBird certificate';

  @override
  String get doorErrLocked => 'Access temporarily locked';

  @override
  String get doorErrConfiguration =>
      'Private DoorBird profile missing or invalid';

  @override
  String get doorErrBusy => 'DoorBird is busy';

  @override
  String get doorErrTimeout => 'Connection interrupted or timed out';

  @override
  String get doorErrVideo => 'Live video interrupted';

  @override
  String get doorErrAudioFocus => 'Panel audio is in use elsewhere';

  @override
  String get doorErrAudioDevice => 'Panel audio unavailable';

  @override
  String get doorErrAudioResponse => 'Invalid audio response – check network';

  @override
  String get doorErrSessionExpired => 'Session expired – start again';

  @override
  String get doorErrConnection => 'Connection failed';

  @override
  String get cameraUnavailable => 'Camera unavailable';

  @override
  String get noPicture => 'No picture';

  @override
  String get lightLow => 'Low';

  @override
  String get lightMid => 'Mid';

  @override
  String get lightFull => 'Full';

  @override
  String get enterCode => 'Enter the code';

  @override
  String get wrongCode => 'Wrong code';

  @override
  String unsupportedCard(String type) {
    return 'Not rendered here: $type';
  }

  @override
  String get companionUnavailable =>
      'Switching to Home Assistant is unavailable on this device';

  @override
  String get updatesLocal => 'Updates managed by local develop build';

  @override
  String updateAvailable(String version) {
    return 'Update $version available';
  }

  @override
  String updateDownloading(String version) {
    return 'Downloading $version…';
  }

  @override
  String updateInstalling(String version) {
    return 'Installing $version…';
  }

  @override
  String updateInstalled(String version) {
    return 'Installed $version, restarting';
  }

  @override
  String updateCheckFailed(String error) {
    return 'Update check failed: $error';
  }

  @override
  String updateInstallFailed(String error) {
    return 'Install failed: $error';
  }

  @override
  String updateFailed(String error) {
    return 'Update failed: $error';
  }
}
