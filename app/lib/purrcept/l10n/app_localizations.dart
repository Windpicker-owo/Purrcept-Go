import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of PhoneL10n
/// returned by `PhoneL10n.of(context)`.
///
/// Applications need to include `PhoneL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: PhoneL10n.localizationsDelegates,
///   supportedLocales: PhoneL10n.supportedLocales,
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
/// be consistent with the languages listed in the PhoneL10n.supportedLocales
/// property.
abstract class PhoneL10n {
  PhoneL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static PhoneL10n of(BuildContext context) {
    return Localizations.of<PhoneL10n>(context, PhoneL10n)!;
  }

  static const LocalizationsDelegate<PhoneL10n> delegate = _PhoneL10nDelegate();

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
    Locale('zh'),
  ];

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection needs attention'**
  String get connectionError;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @device.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get device;

  /// No description provided for @pairTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your Purrcept'**
  String get pairTitle;

  /// No description provided for @pairDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the Phone pairing QR code on your computer, then scan it here. Your agent stays on your computer.'**
  String get pairDescription;

  /// No description provided for @scanPair.
  ///
  /// In en, this message translates to:
  /// **'Scan to pair'**
  String get scanPair;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'The scanner is already open.'**
  String get scanning;

  /// No description provided for @scanDescription.
  ///
  /// In en, this message translates to:
  /// **'The camera is used only to read the invitation. After you confirm the computer, the phone connects automatically. Device control stays off.'**
  String get scanDescription;

  /// No description provided for @manualPairing.
  ///
  /// In en, this message translates to:
  /// **'Other option: paste an invitation'**
  String get manualPairing;

  /// No description provided for @pasteInvitation.
  ///
  /// In en, this message translates to:
  /// **'Paste invitation'**
  String get pasteInvitation;

  /// No description provided for @confirmPairing.
  ///
  /// In en, this message translates to:
  /// **'Confirm your computer'**
  String get confirmPairing;

  /// No description provided for @pairAndConnect.
  ///
  /// In en, this message translates to:
  /// **'Pair and connect'**
  String get pairAndConnect;

  /// No description provided for @confirmHost.
  ///
  /// In en, this message translates to:
  /// **'Connect this phone to {host}?'**
  String confirmHost(String host);

  /// No description provided for @verifyComputer.
  ///
  /// In en, this message translates to:
  /// **'Use only the QR code displayed on your own computer. You can compare the certificate fingerprint below with that screen.'**
  String get verifyComputer;

  /// No description provided for @certificateFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Certificate fingerprint'**
  String get certificateFingerprint;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @cameraPermissionError.
  ///
  /// In en, this message translates to:
  /// **'Camera access was denied. Allow camera access in system settings, or use the paste option.'**
  String get cameraPermissionError;

  /// No description provided for @invitation.
  ///
  /// In en, this message translates to:
  /// **'Pairing invitation'**
  String get invitation;

  /// No description provided for @pair.
  ///
  /// In en, this message translates to:
  /// **'Pair device'**
  String get pair;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @offlineHint.
  ///
  /// In en, this message translates to:
  /// **'Messages will synchronize when your Engine is connected.'**
  String get offlineHint;

  /// No description provided for @emptyChat.
  ///
  /// In en, this message translates to:
  /// **'Say something to Purrcept. She can message you here too.'**
  String get emptyChat;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Saved on phone · waiting for Engine'**
  String get pending;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message Purrcept'**
  String get messageHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get reconnecting;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect now'**
  String get reconnect;

  /// No description provided for @connectingHint.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Engine. Saved messages will synchronize automatically.'**
  String get connectingHint;

  /// No description provided for @acceptedPending.
  ///
  /// In en, this message translates to:
  /// **'Engine accepted · awaiting sync'**
  String get acceptedPending;

  /// No description provided for @engineAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted by Engine'**
  String get engineAccepted;

  /// No description provided for @receivedOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Synced to this phone'**
  String get receivedOnPhone;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'The connection was interrupted. Saved messages will synchronize after reconnection.'**
  String get networkError;

  /// No description provided for @authenticationError.
  ///
  /// In en, this message translates to:
  /// **'Engine rejected this pairing. Check the computer pairing before pairing again.'**
  String get authenticationError;

  /// No description provided for @protocolError.
  ///
  /// In en, this message translates to:
  /// **'The phone and Engine could not communicate. Check their versions and reconnect.'**
  String get protocolError;

  /// No description provided for @invitationError.
  ///
  /// In en, this message translates to:
  /// **'This invitation is invalid. Paste the complete invitation generated by Engine.'**
  String get invitationError;

  /// No description provided for @messageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This message is too long. Shorten it and send again; your draft is preserved.'**
  String get messageTooLarge;

  /// No description provided for @invalidMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a non-empty message within the length limit.'**
  String get invalidMessage;

  /// No description provided for @storageError.
  ///
  /// In en, this message translates to:
  /// **'Phone storage is unavailable. Free some space and retry; unsaved drafts stay in the composer.'**
  String get storageError;

  /// No description provided for @serviceError.
  ///
  /// In en, this message translates to:
  /// **'The phone service is unavailable. Return to the app and try again.'**
  String get serviceError;

  /// No description provided for @notPairedError.
  ///
  /// In en, this message translates to:
  /// **'Pair this phone with your Engine first.'**
  String get notPairedError;

  /// No description provided for @forgetFirstError.
  ///
  /// In en, this message translates to:
  /// **'Forget the current pairing before connecting to another Engine.'**
  String get forgetFirstError;

  /// No description provided for @disconnectFirstError.
  ///
  /// In en, this message translates to:
  /// **'Turn device online off before changing the pairing.'**
  String get disconnectFirstError;

  /// No description provided for @pairingRejected.
  ///
  /// In en, this message translates to:
  /// **'Pairing was rejected or the invitation expired. Generate a fresh invitation on your computer.'**
  String get pairingRejected;

  /// No description provided for @requestFailed.
  ///
  /// In en, this message translates to:
  /// **'The request failed ({code}). Try again after checking the device.'**
  String requestFailed(String code);

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Your Engine'**
  String get host;

  /// No description provided for @stayOnline.
  ///
  /// In en, this message translates to:
  /// **'Device online'**
  String get stayOnline;

  /// No description provided for @onlineDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep the connection active with a visible notification.'**
  String get onlineDescription;

  /// No description provided for @allowControl.
  ///
  /// In en, this message translates to:
  /// **'Allow device control'**
  String get allowControl;

  /// No description provided for @controlDescription.
  ///
  /// In en, this message translates to:
  /// **'Your agent must connect explicitly before reading or operating the screen. Turning this off stops control immediately.'**
  String get controlDescription;

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility service'**
  String get accessibility;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get disabled;

  /// No description provided for @controlSession.
  ///
  /// In en, this message translates to:
  /// **'Agent control session'**
  String get controlSession;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @forget.
  ///
  /// In en, this message translates to:
  /// **'Forget this device pairing'**
  String get forget;

  /// No description provided for @forgetDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove credentials and the phone\'s cached messages. Engine history is preserved. Revoke the pairing on your computer before pairing again.'**
  String get forgetDescription;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'Purrcept Go · Android companion for Purrcept Engine. Derived from dsh-Go by ccch1mneyyy. Source: github.com/Windpicker-owo/Purrcept-Go · AGPL-3.0.'**
  String get about;
}

class _PhoneL10nDelegate extends LocalizationsDelegate<PhoneL10n> {
  const _PhoneL10nDelegate();

  @override
  Future<PhoneL10n> load(Locale locale) {
    return SynchronousFuture<PhoneL10n>(lookupPhoneL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_PhoneL10nDelegate old) => false;
}

PhoneL10n lookupPhoneL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return PhoneL10nEn();
    case 'zh':
      return PhoneL10nZh();
  }

  throw FlutterError(
    'PhoneL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
