import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
  ];

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to Home Assistant'**
  String get connectTitle;

  /// No description provided for @connectHelp.
  ///
  /// In en, this message translates to:
  /// **'Create a long-lived access token under your profile, Security, at the bottom. It is stored on this panel only.'**
  String get connectHelp;

  /// No description provided for @homeAssistantUrl.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant URL'**
  String get homeAssistantUrl;

  /// No description provided for @accessToken.
  ///
  /// In en, this message translates to:
  /// **'Long-lived access token'**
  String get accessToken;

  /// No description provided for @newAccessToken.
  ///
  /// In en, this message translates to:
  /// **'New token (leave empty to keep the current one)'**
  String get newAccessToken;

  /// No description provided for @dashboardPath.
  ///
  /// In en, this message translates to:
  /// **'Dashboard (url path, empty = default)'**
  String get dashboardPath;

  /// No description provided for @dashboardHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. nspanel'**
  String get dashboardHint;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name in Home Assistant'**
  String get deviceName;

  /// No description provided for @deviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'NSPanel Dining'**
  String get deviceNameHint;

  /// No description provided for @mqttBroker.
  ///
  /// In en, this message translates to:
  /// **'MQTT broker (host or host:port, empty = no device)'**
  String get mqttBroker;

  /// No description provided for @mqttBrokerHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 10.0.0.2 or homeassistant.local:1883'**
  String get mqttBrokerHint;

  /// No description provided for @mqttUser.
  ///
  /// In en, this message translates to:
  /// **'MQTT user'**
  String get mqttUser;

  /// No description provided for @mqttPassword.
  ///
  /// In en, this message translates to:
  /// **'MQTT password'**
  String get mqttPassword;

  /// No description provided for @mqttPasswordKept.
  ///
  /// In en, this message translates to:
  /// **'password (kept)'**
  String get mqttPasswordKept;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @urlAndTokenNeeded.
  ///
  /// In en, this message translates to:
  /// **'Both the URL and a token are needed.'**
  String get urlAndTokenNeeded;

  /// No description provided for @noProximitySensor.
  ///
  /// In en, this message translates to:
  /// **'No proximity sensor on this device.'**
  String get noProximitySensor;

  /// No description provided for @proximityNow.
  ///
  /// In en, this message translates to:
  /// **'Proximity sensor now: {value}'**
  String proximityNow(String value);

  /// No description provided for @updateTo.
  ///
  /// In en, this message translates to:
  /// **'Update to {version}'**
  String updateTo(String version);

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkUpdates;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get offline;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @turnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get turnOff;

  /// No description provided for @commandFailed.
  ///
  /// In en, this message translates to:
  /// **'Command failed'**
  String get commandFailed;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @presets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// No description provided for @colour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colour;

  /// No description provided for @white.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get white;

  /// No description provided for @effects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get effects;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @playing.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get playing;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @nothingPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get nothingPlaying;

  /// No description provided for @pausedDetail.
  ///
  /// In en, this message translates to:
  /// **'Paused · {detail}'**
  String pausedDetail(String detail);

  /// No description provided for @onPercent.
  ///
  /// In en, this message translates to:
  /// **'On · {percent}%'**
  String onPercent(String percent);

  /// No description provided for @offLastValues.
  ///
  /// In en, this message translates to:
  /// **'Off · last values'**
  String get offLastValues;

  /// No description provided for @opening.
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get opening;

  /// No description provided for @closing.
  ///
  /// In en, this message translates to:
  /// **'Closing'**
  String get closing;

  /// No description provided for @percentOpen.
  ///
  /// In en, this message translates to:
  /// **'{percent}% open'**
  String percentOpen(String percent);

  /// No description provided for @coverHalf.
  ///
  /// In en, this message translates to:
  /// **'Half'**
  String get coverHalf;

  /// No description provided for @coverShut.
  ///
  /// In en, this message translates to:
  /// **'Shut'**
  String get coverShut;

  /// No description provided for @heat.
  ///
  /// In en, this message translates to:
  /// **'Heat'**
  String get heat;

  /// No description provided for @cool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get cool;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @dryMode.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get dryMode;

  /// No description provided for @fan.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get fan;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @eco.
  ///
  /// In en, this message translates to:
  /// **'Eco'**
  String get eco;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @warm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get warm;

  /// No description provided for @nowTemperature.
  ///
  /// In en, this message translates to:
  /// **'Now {temperature}° · {mode}'**
  String nowTemperature(String temperature, String mode);

  /// No description provided for @missing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missing;

  /// No description provided for @detected.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get detected;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @wet.
  ///
  /// In en, this message translates to:
  /// **'Wet'**
  String get wet;

  /// No description provided for @dryState.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get dryState;

  /// No description provided for @problem.
  ///
  /// In en, this message translates to:
  /// **'Problem'**
  String get problem;

  /// No description provided for @allClear.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get allClear;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @tapAgain.
  ///
  /// In en, this message translates to:
  /// **'Tap again'**
  String get tapAgain;

  /// No description provided for @frequentlyUsed.
  ///
  /// In en, this message translates to:
  /// **'Frequently used'**
  String get frequentlyUsed;

  /// No description provided for @noUsageYet.
  ///
  /// In en, this message translates to:
  /// **'No usage yet'**
  String get noUsageYet;

  /// No description provided for @noResponse.
  ///
  /// In en, this message translates to:
  /// **'No response'**
  String get noResponse;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @hue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get hue;

  /// No description provided for @saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get saturation;

  /// No description provided for @increaseChannel.
  ///
  /// In en, this message translates to:
  /// **'Increase {channel}'**
  String increaseChannel(String channel);

  /// No description provided for @decreaseChannel.
  ///
  /// In en, this message translates to:
  /// **'Decrease {channel}'**
  String decreaseChannel(String channel);

  /// No description provided for @degrees.
  ///
  /// In en, this message translates to:
  /// **'{value} degrees'**
  String degrees(String value);

  /// No description provided for @kelvin.
  ///
  /// In en, this message translates to:
  /// **'{value} kelvin'**
  String kelvin(String value);

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @tokenRejected.
  ///
  /// In en, this message translates to:
  /// **'That token was rejected. Paste a new one.'**
  String get tokenRejected;

  /// No description provided for @noSupportedCards.
  ///
  /// In en, this message translates to:
  /// **'The dashboard \"{path}\" has no cards this app can draw. It needs custom:nspanel-* cards.'**
  String noSupportedCards(String path);

  /// No description provided for @defaultDashboard.
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get defaultDashboard;

  /// No description provided for @defaultDashboardName.
  ///
  /// In en, this message translates to:
  /// **'the default dashboard'**
  String get defaultDashboardName;

  /// No description provided for @dashboardLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load {name}: {error}'**
  String dashboardLoadFailed(String name, String error);

  /// No description provided for @dashboardAutoGenerated.
  ///
  /// In en, this message translates to:
  /// **'Dashboard \"{path}\" exists but has no saved config yet. In Home Assistant open it, then ⋮ → Edit dashboard → Take control, add the nspanel cards and save. This panel reloads on its own.'**
  String dashboardAutoGenerated(String path);

  /// No description provided for @dashboardKnown.
  ///
  /// In en, this message translates to:
  /// **'Could not load {name}: {error}\n\nDashboards on this Home Assistant:\n{paths}\n\nHold two fingers to change it.'**
  String dashboardKnown(String name, String error, String paths);

  /// No description provided for @defaultDashboardEntry.
  ///
  /// In en, this message translates to:
  /// **'(empty) for the default dashboard'**
  String get defaultDashboardEntry;

  /// No description provided for @weatherSunny.
  ///
  /// In en, this message translates to:
  /// **'Sunny'**
  String get weatherSunny;

  /// No description provided for @weatherClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get weatherClear;

  /// No description provided for @weatherCloudy.
  ///
  /// In en, this message translates to:
  /// **'Cloudy'**
  String get weatherCloudy;

  /// No description provided for @weatherFog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get weatherFog;

  /// No description provided for @weatherHail.
  ///
  /// In en, this message translates to:
  /// **'Hail'**
  String get weatherHail;

  /// No description provided for @weatherLightning.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weatherLightning;

  /// No description provided for @weatherThunderRain.
  ///
  /// In en, this message translates to:
  /// **'Thunder, rain'**
  String get weatherThunderRain;

  /// No description provided for @weatherPartlyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get weatherPartlyCloudy;

  /// No description provided for @weatherPouring.
  ///
  /// In en, this message translates to:
  /// **'Heavy rain'**
  String get weatherPouring;

  /// No description provided for @weatherRainy.
  ///
  /// In en, this message translates to:
  /// **'Rainy'**
  String get weatherRainy;

  /// No description provided for @weatherSnowy.
  ///
  /// In en, this message translates to:
  /// **'Snowy'**
  String get weatherSnowy;

  /// No description provided for @weatherSleet.
  ///
  /// In en, this message translates to:
  /// **'Sleet'**
  String get weatherSleet;

  /// No description provided for @weatherWindy.
  ///
  /// In en, this message translates to:
  /// **'Windy'**
  String get weatherWindy;

  /// No description provided for @weatherSevere.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get weatherSevere;

  /// No description provided for @byPerson.
  ///
  /// In en, this message translates to:
  /// **'{name} · by {person}'**
  String byPerson(String name, String person);

  /// No description provided for @alarmHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get alarmHome;

  /// No description provided for @alarmAway.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get alarmAway;

  /// No description provided for @alarmNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get alarmNight;

  /// No description provided for @alarmBypass.
  ///
  /// In en, this message translates to:
  /// **'Bypass'**
  String get alarmBypass;

  /// No description provided for @alarmVacation.
  ///
  /// In en, this message translates to:
  /// **'Vacation'**
  String get alarmVacation;

  /// No description provided for @alarmDisarmed.
  ///
  /// In en, this message translates to:
  /// **'Disarmed'**
  String get alarmDisarmed;

  /// No description provided for @alarmArmedHome.
  ///
  /// In en, this message translates to:
  /// **'Armed home'**
  String get alarmArmedHome;

  /// No description provided for @alarmArmedAway.
  ///
  /// In en, this message translates to:
  /// **'Armed away'**
  String get alarmArmedAway;

  /// No description provided for @alarmArmedNight.
  ///
  /// In en, this message translates to:
  /// **'Armed night'**
  String get alarmArmedNight;

  /// No description provided for @alarmArmedVacation.
  ///
  /// In en, this message translates to:
  /// **'Armed vacation'**
  String get alarmArmedVacation;

  /// No description provided for @alarmArmedBypass.
  ///
  /// In en, this message translates to:
  /// **'Armed (bypass)'**
  String get alarmArmedBypass;

  /// No description provided for @alarmArming.
  ///
  /// In en, this message translates to:
  /// **'Arming…'**
  String get alarmArming;

  /// No description provided for @alarmDisarming.
  ///
  /// In en, this message translates to:
  /// **'Disarming…'**
  String get alarmDisarming;

  /// No description provided for @alarmPending.
  ///
  /// In en, this message translates to:
  /// **'Pending…'**
  String get alarmPending;

  /// No description provided for @alarmTriggered.
  ///
  /// In en, this message translates to:
  /// **'TRIGGERED'**
  String get alarmTriggered;

  /// No description provided for @alarmDisarm.
  ///
  /// In en, this message translates to:
  /// **'Disarm'**
  String get alarmDisarm;

  /// No description provided for @alarmArmMode.
  ///
  /// In en, this message translates to:
  /// **'Arm {mode}'**
  String alarmArmMode(String mode);

  /// No description provided for @doorVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get doorVolume;

  /// No description provided for @doorBuzzer.
  ///
  /// In en, this message translates to:
  /// **'Door buzzer'**
  String get doorBuzzer;

  /// No description provided for @doorConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Only after confirmation'**
  String get doorConfirmRequired;

  /// No description provided for @doorConfirmPrompt.
  ///
  /// In en, this message translates to:
  /// **'Activate the front door buzzer?'**
  String get doorConfirmPrompt;

  /// No description provided for @doorCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get doorCancel;

  /// No description provided for @doorSend.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get doorSend;

  /// No description provided for @doorSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get doorSending;

  /// No description provided for @doorSent.
  ///
  /// In en, this message translates to:
  /// **'Command sent'**
  String get doorSent;

  /// No description provided for @doorUncertain.
  ///
  /// In en, this message translates to:
  /// **'Outcome unclear – check the door'**
  String get doorUncertain;

  /// No description provided for @doorConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting · Mic off'**
  String get doorConnecting;

  /// No description provided for @doorStill.
  ///
  /// In en, this message translates to:
  /// **'Still image · Mic off'**
  String get doorStill;

  /// No description provided for @doorCallConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting call · Mic off'**
  String get doorCallConnecting;

  /// No description provided for @doorTalking.
  ///
  /// In en, this message translates to:
  /// **'Call · Mic on'**
  String get doorTalking;

  /// No description provided for @doorMuted.
  ///
  /// In en, this message translates to:
  /// **'Call · Mic off'**
  String get doorMuted;

  /// No description provided for @doorEnding.
  ///
  /// In en, this message translates to:
  /// **'Ending · Mic off'**
  String get doorEnding;

  /// No description provided for @doorLiveListen.
  ///
  /// In en, this message translates to:
  /// **'Live · Listen · Mic off'**
  String get doorLiveListen;

  /// No description provided for @doorListen.
  ///
  /// In en, this message translates to:
  /// **'Listen · Mic off'**
  String get doorListen;

  /// No description provided for @doorVideoReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting video…'**
  String get doorVideoReconnecting;

  /// No description provided for @doorVideoConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting video…'**
  String get doorVideoConnecting;

  /// No description provided for @doorEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get doorEnd;

  /// No description provided for @doorLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get doorLive;

  /// No description provided for @doorMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get doorMute;

  /// No description provided for @doorSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get doorSpeak;

  /// No description provided for @doorQuieter.
  ///
  /// In en, this message translates to:
  /// **'Quieter'**
  String get doorQuieter;

  /// No description provided for @doorLouder.
  ///
  /// In en, this message translates to:
  /// **'Louder'**
  String get doorLouder;

  /// No description provided for @doorVolumePercent.
  ///
  /// In en, this message translates to:
  /// **'Volume {percent} percent'**
  String doorVolumePercent(String percent);

  /// No description provided for @doorErrPermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone or DoorBird access denied'**
  String get doorErrPermission;

  /// No description provided for @doorErrAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Check DoorBird credentials'**
  String get doorErrAuthentication;

  /// No description provided for @doorErrCertificate.
  ///
  /// In en, this message translates to:
  /// **'Check DoorBird certificate'**
  String get doorErrCertificate;

  /// No description provided for @doorErrLocked.
  ///
  /// In en, this message translates to:
  /// **'Access temporarily locked'**
  String get doorErrLocked;

  /// No description provided for @doorErrConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Private DoorBird profile missing or invalid'**
  String get doorErrConfiguration;

  /// No description provided for @doorErrBusy.
  ///
  /// In en, this message translates to:
  /// **'DoorBird is busy'**
  String get doorErrBusy;

  /// No description provided for @doorErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection interrupted or timed out'**
  String get doorErrTimeout;

  /// No description provided for @doorErrVideo.
  ///
  /// In en, this message translates to:
  /// **'Live video interrupted'**
  String get doorErrVideo;

  /// No description provided for @doorErrAudioFocus.
  ///
  /// In en, this message translates to:
  /// **'Panel audio is in use elsewhere'**
  String get doorErrAudioFocus;

  /// No description provided for @doorErrAudioDevice.
  ///
  /// In en, this message translates to:
  /// **'Panel audio unavailable'**
  String get doorErrAudioDevice;

  /// No description provided for @doorErrAudioResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid audio response – check network'**
  String get doorErrAudioResponse;

  /// No description provided for @doorErrSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired – start again'**
  String get doorErrSessionExpired;

  /// No description provided for @doorErrConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get doorErrConnection;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get cameraUnavailable;

  /// No description provided for @noPicture.
  ///
  /// In en, this message translates to:
  /// **'No picture'**
  String get noPicture;

  /// No description provided for @lightLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get lightLow;

  /// No description provided for @lightMid.
  ///
  /// In en, this message translates to:
  /// **'Mid'**
  String get lightMid;

  /// No description provided for @lightFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get lightFull;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get enterCode;

  /// No description provided for @wrongCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong code'**
  String get wrongCode;

  /// No description provided for @unsupportedCard.
  ///
  /// In en, this message translates to:
  /// **'Not rendered here: {type}'**
  String unsupportedCard(String type);

  /// No description provided for @companionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Switching to Home Assistant is unavailable on this device'**
  String get companionUnavailable;

  /// No description provided for @updatesLocal.
  ///
  /// In en, this message translates to:
  /// **'Updates managed by local develop build'**
  String get updatesLocal;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update {version} available'**
  String updateAvailable(String version);

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {version}…'**
  String updateDownloading(String version);

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing {version}…'**
  String updateInstalling(String version);

  /// No description provided for @updateInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed {version}, restarting'**
  String updateInstalled(String version);

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed: {error}'**
  String updateCheckFailed(String error);

  /// No description provided for @updateInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Install failed: {error}'**
  String updateInstallFailed(String error);

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String updateFailed(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
