// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get connectTitle => 'Mit Home Assistant verbinden';

  @override
  String get connectHelp =>
      'Erstelle unter Profil → Sicherheit ganz unten ein langlebiges Zugriffstoken. Es wird nur auf diesem Panel gespeichert.';

  @override
  String get homeAssistantUrl => 'Home-Assistant-URL';

  @override
  String get accessToken => 'Langlebiges Zugriffstoken';

  @override
  String get newAccessToken =>
      'Neues Token (leer lassen, um das bisherige zu behalten)';

  @override
  String get dashboardPath => 'Dashboard (URL-Pfad, leer = Standard)';

  @override
  String get dashboardHint => 'z. B. nspanel';

  @override
  String get deviceName => 'Gerätename in Home Assistant';

  @override
  String get deviceNameHint => 'NSPanel Essen';

  @override
  String get mqttBroker =>
      'MQTT-Broker (Host oder Host:Port, leer = kein Gerät)';

  @override
  String get mqttBrokerHint => 'z. B. 10.0.0.2 oder homeassistant.local:1883';

  @override
  String get mqttUser => 'MQTT-Benutzer';

  @override
  String get mqttPassword => 'MQTT-Passwort';

  @override
  String get mqttPasswordKept => 'Passwort (gespeichert)';

  @override
  String get connect => 'Verbinden';

  @override
  String get urlAndTokenNeeded => 'URL und Token werden benötigt.';

  @override
  String get noProximitySensor => 'Dieses Gerät hat keinen Näherungssensor.';

  @override
  String proximityNow(String value) {
    return 'Näherungssensor: $value';
  }

  @override
  String updateTo(String version) {
    return 'Update auf $version';
  }

  @override
  String get checkUpdates => 'Nach Updates suchen';

  @override
  String get close => 'Schließen';

  @override
  String get increase => 'Erhöhen';

  @override
  String get decrease => 'Verringern';

  @override
  String get on => 'An';

  @override
  String get off => 'Aus';

  @override
  String get open => 'Offen';

  @override
  String get closed => 'Geschlossen';

  @override
  String get stop => 'Stopp';

  @override
  String get unavailable => 'Nicht verfügbar';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get loading => 'Lädt…';

  @override
  String get offline => 'OFFLINE';

  @override
  String get turnOn => 'Einschalten';

  @override
  String get turnOff => 'Ausschalten';

  @override
  String get commandFailed => 'Befehl fehlgeschlagen';

  @override
  String get back => 'Zurück';

  @override
  String get presets => 'Vorgaben';

  @override
  String get colour => 'Farbe';

  @override
  String get white => 'Weiß';

  @override
  String get effects => 'Effekte';

  @override
  String get previous => 'Zurück';

  @override
  String get next => 'Weiter';

  @override
  String get play => 'Abspielen';

  @override
  String get pause => 'Pause';

  @override
  String get playing => 'Spielt';

  @override
  String get paused => 'Pausiert';

  @override
  String get nothingPlaying => 'Keine Wiedergabe';

  @override
  String pausedDetail(String detail) {
    return 'Pausiert · $detail';
  }

  @override
  String onPercent(String percent) {
    return 'An · $percent%';
  }

  @override
  String get offLastValues => 'Aus · letzte Werte';

  @override
  String get opening => 'Öffnet';

  @override
  String get closing => 'Schließt';

  @override
  String percentOpen(String percent) {
    return '$percent% offen';
  }

  @override
  String get coverHalf => 'Halb';

  @override
  String get coverShut => 'Zu';

  @override
  String get heat => 'Heizen';

  @override
  String get cool => 'Kühlen';

  @override
  String get auto => 'Auto';

  @override
  String get dryMode => 'Entfeuchten';

  @override
  String get fan => 'Lüfter';

  @override
  String get idle => 'Bereit';

  @override
  String get eco => 'Eco';

  @override
  String get day => 'Tag';

  @override
  String get warm => 'Warm';

  @override
  String nowTemperature(String temperature, String mode) {
    return 'Jetzt $temperature° · $mode';
  }

  @override
  String get missing => 'Fehlt';

  @override
  String get detected => 'Erkannt';

  @override
  String get clear => 'Frei';

  @override
  String get wet => 'Nass';

  @override
  String get dryState => 'Trocken';

  @override
  String get problem => 'Problem';

  @override
  String get allClear => 'Alles in Ordnung';

  @override
  String get run => 'Ausführen';

  @override
  String get tapAgain => 'Erneut tippen';

  @override
  String get frequentlyUsed => 'Häufig genutzt';

  @override
  String get noUsageYet => 'Noch keine Nutzung';

  @override
  String get noResponse => 'Keine Antwort';

  @override
  String get brightness => 'Helligkeit';

  @override
  String get temperature => 'Farbtemperatur';

  @override
  String get hue => 'Farbton';

  @override
  String get saturation => 'Sättigung';

  @override
  String increaseChannel(String channel) {
    return '$channel erhöhen';
  }

  @override
  String decreaseChannel(String channel) {
    return '$channel verringern';
  }

  @override
  String degrees(String value) {
    return '$value Grad';
  }

  @override
  String kelvin(String value) {
    return '$value Kelvin';
  }

  @override
  String get connecting => 'Verbinden…';

  @override
  String get tokenRejected =>
      'Das Token wurde abgelehnt. Bitte ein neues eingeben.';

  @override
  String noSupportedCards(String path) {
    return 'Das Dashboard \"$path\" enthält keine Karten, die diese App anzeigen kann. Benötigt werden custom:nspanel-*-Karten.';
  }

  @override
  String get defaultDashboard => 'Standard';

  @override
  String get defaultDashboardName => 'das Standard-Dashboard';

  @override
  String dashboardLoadFailed(String name, String error) {
    return '$name konnte nicht geladen werden: $error';
  }

  @override
  String dashboardAutoGenerated(String path) {
    return 'Dashboard \"$path\" ist vorhanden, aber noch automatisch erzeugt. Öffne es in Home Assistant und wähle ⋮ → Dashboard bearbeiten → Kontrolle übernehmen. Füge die NSPanel-Karten hinzu und speichere. Dieses Panel lädt danach selbst neu.';
  }

  @override
  String dashboardKnown(String name, String error, String paths) {
    return '$name konnte nicht geladen werden: $error\n\nDashboards in Home Assistant:\n$paths\n\nZum Ändern zwei Finger gedrückt halten.';
  }

  @override
  String get defaultDashboardEntry => '(leer) für das Standard-Dashboard';

  @override
  String get weatherSunny => 'Sonnig';

  @override
  String get weatherClear => 'Klar';

  @override
  String get weatherCloudy => 'Bewölkt';

  @override
  String get weatherFog => 'Nebel';

  @override
  String get weatherHail => 'Hagel';

  @override
  String get weatherLightning => 'Gewitter';

  @override
  String get weatherThunderRain => 'Gewitter, Regen';

  @override
  String get weatherPartlyCloudy => 'Teilweise bewölkt';

  @override
  String get weatherPouring => 'Starkregen';

  @override
  String get weatherRainy => 'Regnerisch';

  @override
  String get weatherSnowy => 'Schnee';

  @override
  String get weatherSleet => 'Schneeregen';

  @override
  String get weatherWindy => 'Windig';

  @override
  String get weatherSevere => 'Unwetter';

  @override
  String byPerson(String name, String person) {
    return '$name · von $person';
  }

  @override
  String get alarmHome => 'Zuhause';

  @override
  String get alarmAway => 'Abwesend';

  @override
  String get alarmNight => 'Nacht';

  @override
  String get alarmBypass => 'Umgehen';

  @override
  String get alarmVacation => 'Urlaub';

  @override
  String get alarmDisarmed => 'Unscharf';

  @override
  String get alarmArmedHome => 'Scharf: Zuhause';

  @override
  String get alarmArmedAway => 'Scharf: Abwesend';

  @override
  String get alarmArmedNight => 'Scharf: Nacht';

  @override
  String get alarmArmedVacation => 'Scharf: Urlaub';

  @override
  String get alarmArmedBypass => 'Scharf (umgangen)';

  @override
  String get alarmArming => 'Wird scharfgeschaltet…';

  @override
  String get alarmDisarming => 'Wird entschärft…';

  @override
  String get alarmPending => 'Warten…';

  @override
  String get alarmTriggered => 'ALARM';

  @override
  String get alarmDisarm => 'Entschärfen';

  @override
  String alarmArmMode(String mode) {
    return '$mode scharfschalten';
  }

  @override
  String get doorVolume => 'Lautstärke';

  @override
  String get doorBuzzer => 'Türsummer';

  @override
  String get doorConfirmRequired => 'Nur nach Bestätigung';

  @override
  String get doorConfirmPrompt => 'Türsummer an der Eingangstür auslösen?';

  @override
  String get doorCancel => 'Abbrechen';

  @override
  String get doorSend => 'Auslösen';

  @override
  String get doorSending => 'Wird gesendet …';

  @override
  String get doorSent => 'Befehl gesendet';

  @override
  String get doorUncertain => 'Ergebnis unklar – Tür prüfen';

  @override
  String get doorConnecting => 'Verbinden · Mikrofon aus';

  @override
  String get doorStill => 'Standbild · Mikrofon aus';

  @override
  String get doorCallConnecting => 'Gespräch verbinden · Mikrofon aus';

  @override
  String get doorTalking => 'Gespräch · Mikrofon an';

  @override
  String get doorMuted => 'Gespräch · Mikrofon aus';

  @override
  String get doorEnding => 'Beenden · Mikrofon aus';

  @override
  String get doorLiveListen => 'Live · Hören · Mikrofon aus';

  @override
  String get doorListen => 'Hören · Mikrofon aus';

  @override
  String get doorVideoReconnecting => 'Video verbindet erneut …';

  @override
  String get doorVideoConnecting => 'Video wird verbunden …';

  @override
  String get doorEnd => 'Beenden';

  @override
  String get doorLive => 'Live';

  @override
  String get doorMute => 'Stumm';

  @override
  String get doorSpeak => 'Sprechen';

  @override
  String get doorQuieter => 'Leiser';

  @override
  String get doorLouder => 'Lauter';

  @override
  String doorVolumePercent(String percent) {
    return 'Lautstärke $percent Prozent';
  }

  @override
  String get doorErrPermission =>
      'Mikrofon oder DoorBird-Zugriff nicht erlaubt';

  @override
  String get doorErrAuthentication => 'DoorBird-Zugang prüfen';

  @override
  String get doorErrCertificate => 'DoorBird-Zertifikat prüfen';

  @override
  String get doorErrLocked => 'Zugang vorübergehend gesperrt';

  @override
  String get doorErrConfiguration =>
      'Privates DoorBird-Profil fehlt oder ist ungültig';

  @override
  String get doorErrBusy => 'DoorBird ist besetzt';

  @override
  String get doorErrTimeout =>
      'Verbindung unterbrochen oder Zeitüberschreitung';

  @override
  String get doorErrVideo => 'Livevideo unterbrochen';

  @override
  String get doorErrAudioFocus => 'Panel-Audio wird anderweitig verwendet';

  @override
  String get doorErrAudioDevice => 'Panel-Audio nicht verfügbar';

  @override
  String get doorErrAudioResponse => 'Audioantwort ungültig – Netzwerk prüfen';

  @override
  String get doorErrSessionExpired => 'Sitzung abgelaufen – bitte neu starten';

  @override
  String get doorErrConnection => 'Verbindung fehlgeschlagen';

  @override
  String get cameraUnavailable => 'Kamera nicht verfügbar';

  @override
  String get noPicture => 'Kein Bild';

  @override
  String get lightLow => 'Niedrig';

  @override
  String get lightMid => 'Mittel';

  @override
  String get lightFull => 'Voll';

  @override
  String get enterCode => 'Code eingeben';

  @override
  String get wrongCode => 'Falscher Code';

  @override
  String unsupportedCard(String type) {
    return 'Hier nicht darstellbar: $type';
  }

  @override
  String get companionUnavailable =>
      'Wechsel zu Home Assistant auf diesem Gerät nicht verfügbar';

  @override
  String get updatesLocal =>
      'Updates werden vom lokalen Develop-Build verwaltet';

  @override
  String updateAvailable(String version) {
    return 'Update $version verfügbar';
  }

  @override
  String updateDownloading(String version) {
    return '$version wird heruntergeladen…';
  }

  @override
  String updateInstalling(String version) {
    return '$version wird installiert…';
  }

  @override
  String updateInstalled(String version) {
    return '$version installiert, Neustart…';
  }

  @override
  String updateCheckFailed(String error) {
    return 'Updateprüfung fehlgeschlagen: $error';
  }

  @override
  String updateInstallFailed(String error) {
    return 'Installation fehlgeschlagen: $error';
  }

  @override
  String updateFailed(String error) {
    return 'Update fehlgeschlagen: $error';
  }
}
