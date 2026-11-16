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
  /// **'A place to pick up the conversation.'**
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
  /// **'A thought, a question, your day…'**
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

  /// No description provided for @companionFallback.
  ///
  /// In en, this message translates to:
  /// **'Your companion'**
  String get companionFallback;

  /// No description provided for @activityReady.
  ///
  /// In en, this message translates to:
  /// **'Here with you'**
  String get activityReady;

  /// No description provided for @activityReceiving.
  ///
  /// In en, this message translates to:
  /// **'Your message reached the computer'**
  String get activityReceiving;

  /// No description provided for @activityProcessing.
  ///
  /// In en, this message translates to:
  /// **'Taking in the current inputs'**
  String get activityProcessing;

  /// No description provided for @activityThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get activityThinking;

  /// No description provided for @activityActing.
  ///
  /// In en, this message translates to:
  /// **'Taking action'**
  String get activityActing;

  /// No description provided for @activityOffline.
  ///
  /// In en, this message translates to:
  /// **'Connection is offline'**
  String get activityOffline;

  /// No description provided for @activityConnecting.
  ///
  /// In en, this message translates to:
  /// **'Finding your Engine'**
  String get activityConnecting;

  /// No description provided for @activitySynchronizing.
  ///
  /// In en, this message translates to:
  /// **'Syncing live status'**
  String get activitySynchronizing;

  /// No description provided for @activityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Connected · activity unavailable'**
  String get activityUnavailable;

  /// No description provided for @activityStarting.
  ///
  /// In en, this message translates to:
  /// **'Engine is getting ready'**
  String get activityStarting;

  /// No description provided for @detailReady.
  ///
  /// In en, this message translates to:
  /// **'Send a thought, or carry on with your day.'**
  String get detailReady;

  /// No description provided for @detailReceiving.
  ///
  /// In en, this message translates to:
  /// **'The message is recorded. Waiting for the agent to take it into a turn.'**
  String get detailReceiving;

  /// No description provided for @detailProcessing.
  ///
  /// In en, this message translates to:
  /// **'A turn has started. Thought and action progress will appear here.'**
  String get detailProcessing;

  /// No description provided for @detailThinking.
  ///
  /// In en, this message translates to:
  /// **'Your companion is thinking. You can keep chatting.'**
  String get detailThinking;

  /// No description provided for @detailActing.
  ///
  /// In en, this message translates to:
  /// **'An action is running. Its outcome will follow the actual result.'**
  String get detailActing;

  /// No description provided for @detailOffline.
  ///
  /// In en, this message translates to:
  /// **'Messages saved on this phone will sync after reconnecting. Live activity is unknown.'**
  String get detailOffline;

  /// No description provided for @detailConnecting.
  ///
  /// In en, this message translates to:
  /// **'Saved messages stay here while the connection returns.'**
  String get detailConnecting;

  /// No description provided for @detailSynchronizing.
  ///
  /// In en, this message translates to:
  /// **'The connection is up. Waiting for the first authoritative status.'**
  String get detailSynchronizing;

  /// No description provided for @detailUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This computer app does not provide live progress yet. You can keep chatting and update it later.'**
  String get detailUnavailable;

  /// No description provided for @detailStarting.
  ///
  /// In en, this message translates to:
  /// **'The computer is preparing its agent. Message admission and thought are separate.'**
  String get detailStarting;

  /// No description provided for @messageWaiting.
  ///
  /// In en, this message translates to:
  /// **'In the inbox · waiting for a turn'**
  String get messageWaiting;

  /// No description provided for @messageClaimed.
  ///
  /// In en, this message translates to:
  /// **'Taken into a turn'**
  String get messageClaimed;

  /// No description provided for @messageThinking.
  ///
  /// In en, this message translates to:
  /// **'Current turn · thinking'**
  String get messageThinking;

  /// No description provided for @messageActing.
  ///
  /// In en, this message translates to:
  /// **'Current turn · action running'**
  String get messageActing;

  /// No description provided for @messageFinished.
  ///
  /// In en, this message translates to:
  /// **'This turn has finished'**
  String get messageFinished;

  /// No description provided for @messageRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded during rest'**
  String get messageRecorded;

  /// No description provided for @messageFailed.
  ///
  /// In en, this message translates to:
  /// **'This turn did not finish successfully'**
  String get messageFailed;

  /// No description provided for @messageStale.
  ///
  /// In en, this message translates to:
  /// **'Accepted · reconnect to refresh progress'**
  String get messageStale;

  /// No description provided for @activityDetails.
  ///
  /// In en, this message translates to:
  /// **'What this status means'**
  String get activityDetails;

  /// No description provided for @statusNotReply.
  ///
  /// In en, this message translates to:
  /// **'Processing a message does not always produce a reply. Actions and messages are shown only after they actually happen.'**
  String get statusNotReply;

  /// No description provided for @actionPhone.
  ///
  /// In en, this message translates to:
  /// **'Working with the phone'**
  String get actionPhone;

  /// No description provided for @actionComputer.
  ///
  /// In en, this message translates to:
  /// **'Working with the computer'**
  String get actionComputer;

  /// No description provided for @actionNotebook.
  ///
  /// In en, this message translates to:
  /// **'Organizing notes'**
  String get actionNotebook;

  /// No description provided for @actionBrowser.
  ///
  /// In en, this message translates to:
  /// **'Looking up information'**
  String get actionBrowser;

  /// No description provided for @actionMessage.
  ///
  /// In en, this message translates to:
  /// **'Sending a message'**
  String get actionMessage;

  /// No description provided for @conversationHint.
  ///
  /// In en, this message translates to:
  /// **'A thought, a question, your day…'**
  String get conversationHint;

  /// No description provided for @setupWelcome.
  ///
  /// In en, this message translates to:
  /// **'Bring your companion along'**
  String get setupWelcome;

  /// No description provided for @setupWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Your companion lives on your computer. This phone is a window for conversations and, when you allow it, a way to act on your phone.'**
  String get setupWelcomeBody;

  /// No description provided for @setupBegin.
  ///
  /// In en, this message translates to:
  /// **'Let’s connect'**
  String get setupBegin;

  /// No description provided for @setupComputer.
  ///
  /// In en, this message translates to:
  /// **'First, your computer'**
  String get setupComputer;

  /// No description provided for @setupComputerBody.
  ///
  /// In en, this message translates to:
  /// **'Your companion stays on the computer. Put this phone and the computer on the same Wi-Fi, or use the private network you already configured.'**
  String get setupComputerBody;

  /// No description provided for @setupComputerSteps.
  ///
  /// In en, this message translates to:
  /// **'Open Engine’s WebUI on your computer, then Devices → Connect Android phone. For first-time setup, open Phone connection settings, choose the computer address, preview and save, then restart Engine normally. Select Show pairing QR code and return here to scan.'**
  String get setupComputerSteps;

  /// No description provided for @setupComputerHelp.
  ///
  /// In en, this message translates to:
  /// **'No QR code?'**
  String get setupComputerHelp;

  /// No description provided for @setupComputerTrouble.
  ///
  /// In en, this message translates to:
  /// **'Select Show pairing QR code on Engine’s Devices page. Refresh an expired QR without restarting Engine. If Phone is not enabled, save its settings there and restart normally. If already paired, connect directly from this phone.'**
  String get setupComputerTrouble;

  /// No description provided for @setupHaveQr.
  ///
  /// In en, this message translates to:
  /// **'The QR code is ready'**
  String get setupHaveQr;

  /// No description provided for @setupBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get setupBack;

  /// No description provided for @setupChoices.
  ///
  /// In en, this message translates to:
  /// **'Make it yours'**
  String get setupChoices;

  /// No description provided for @setupChoicesBody.
  ///
  /// In en, this message translates to:
  /// **'Pairing is saved. You can chat now. The permissions below are optional and can be changed later in Device.'**
  String get setupChoicesBody;

  /// No description provided for @setupNotifications.
  ///
  /// In en, this message translates to:
  /// **'Know when a message arrives'**
  String get setupNotifications;

  /// No description provided for @setupNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications to see new messages while using other apps. You can still chat without them.'**
  String get setupNotificationsBody;

  /// No description provided for @setupEnableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow message notifications'**
  String get setupEnableNotifications;

  /// No description provided for @setupNotificationsReady.
  ///
  /// In en, this message translates to:
  /// **'Notifications are enabled'**
  String get setupNotificationsReady;

  /// No description provided for @setupControl.
  ///
  /// In en, this message translates to:
  /// **'Let your companion use this phone'**
  String get setupControl;

  /// No description provided for @setupControlBody.
  ///
  /// In en, this message translates to:
  /// **'For screen reading and gestures, enable Purrcept Go in Android Accessibility, then turn on Allow device control. Your companion still has to establish a control session explicitly. Chat needs neither permission.'**
  String get setupControlBody;

  /// No description provided for @setupOpenAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Open Accessibility settings'**
  String get setupOpenAccessibility;

  /// No description provided for @setupStartChat.
  ///
  /// In en, this message translates to:
  /// **'Start chatting'**
  String get setupStartChat;

  /// No description provided for @setupRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get setupRetry;

  /// No description provided for @setupProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String setupProgress(int current, int total);

  /// No description provided for @activityClosing.
  ///
  /// In en, this message translates to:
  /// **'Engine is finishing up'**
  String get activityClosing;

  /// No description provided for @activityStopped.
  ///
  /// In en, this message translates to:
  /// **'Engine has stopped'**
  String get activityStopped;

  /// No description provided for @activityFailed.
  ///
  /// In en, this message translates to:
  /// **'Engine needs attention'**
  String get activityFailed;

  /// No description provided for @detailClosing.
  ///
  /// In en, this message translates to:
  /// **'The computer is closing its agent. Existing actions may still be finishing.'**
  String get detailClosing;

  /// No description provided for @detailStopped.
  ///
  /// In en, this message translates to:
  /// **'Start Engine on your computer to continue. Saved messages stay on this phone.'**
  String get detailStopped;

  /// No description provided for @detailFailed.
  ///
  /// In en, this message translates to:
  /// **'Check Engine on your computer. The phone cannot infer current work from this failure.'**
  String get detailFailed;

  /// No description provided for @messageDetails.
  ///
  /// In en, this message translates to:
  /// **'Message progress'**
  String get messageDetails;

  /// No description provided for @messageDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the status of a message to see its last known progress.'**
  String get messageDetailsHint;

  /// No description provided for @recentAction.
  ///
  /// In en, this message translates to:
  /// **'Last associated action'**
  String get recentAction;

  /// No description provided for @receiptConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Execution receipt confirmed'**
  String get receiptConfirmed;

  /// No description provided for @receiptFailed.
  ///
  /// In en, this message translates to:
  /// **'Execution failed'**
  String get receiptFailed;

  /// No description provided for @receiptUnknown.
  ///
  /// In en, this message translates to:
  /// **'Outcome unknown'**
  String get receiptUnknown;

  /// No description provided for @receiptStarted.
  ///
  /// In en, this message translates to:
  /// **'Dispatched · no result observed yet'**
  String get receiptStarted;

  /// No description provided for @noAssociatedAction.
  ///
  /// In en, this message translates to:
  /// **'No associated action has been reported in this observation.'**
  String get noAssociatedAction;

  /// No description provided for @receiptExplanation.
  ///
  /// In en, this message translates to:
  /// **'This is the last recorded call, not a complete action history. A confirmed receipt does not guarantee that the app on the phone finished its business task.'**
  String get receiptExplanation;

  /// No description provided for @messageProgressUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Accepted · current progress unavailable'**
  String get messageProgressUnavailable;

  /// No description provided for @messageProgressUnavailableDetail.
  ///
  /// In en, this message translates to:
  /// **'The computer has not provided a fresh status for this message. Confirmed outcomes are kept. Without a current record, the phone cannot say whether this message is still being processed or has finished.'**
  String get messageProgressUnavailableDetail;

  /// No description provided for @actionNamePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone operation'**
  String get actionNamePhone;

  /// No description provided for @actionNameComputer.
  ///
  /// In en, this message translates to:
  /// **'Computer operation'**
  String get actionNameComputer;

  /// No description provided for @actionNameNotebook.
  ///
  /// In en, this message translates to:
  /// **'Note organization'**
  String get actionNameNotebook;

  /// No description provided for @actionNameBrowser.
  ///
  /// In en, this message translates to:
  /// **'Web operation'**
  String get actionNameBrowser;

  /// No description provided for @actionNameMessage.
  ///
  /// In en, this message translates to:
  /// **'Message delivery'**
  String get actionNameMessage;

  /// No description provided for @actionNameOther.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get actionNameOther;

  /// No description provided for @pairingNetworkError.
  ///
  /// In en, this message translates to:
  /// **'The computer connection failed before pairing completed. Check the address, app Wi-Fi permission or proxy settings, then refresh and scan a new QR.'**
  String get pairingNetworkError;

  /// No description provided for @networkTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'The computer connection timed out. Check Wi-Fi, proxy settings or network client isolation.'**
  String get networkTimeoutError;

  /// No description provided for @computerUnreachableError.
  ///
  /// In en, this message translates to:
  /// **'The computer’s Phone service is unreachable. Check Engine, the pairing address and the port.'**
  String get computerUnreachableError;

  /// No description provided for @computerNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'The computer address could not be resolved. Check it in Engine WebUI.'**
  String get computerNotFoundError;

  /// No description provided for @networkPermissionError.
  ///
  /// In en, this message translates to:
  /// **'The system blocked this app’s network access. Allow Purrcept Go to use Wi-Fi in app network permissions.'**
  String get networkPermissionError;

  /// No description provided for @certificateDateError.
  ///
  /// In en, this message translates to:
  /// **'Certificate date validation failed. Check the phone and computer clocks, then the certificate expiry.'**
  String get certificateDateError;

  /// No description provided for @certificateMismatchError.
  ///
  /// In en, this message translates to:
  /// **'The computer certificate does not match the QR. Refresh the QR in Engine WebUI and scan it again.'**
  String get certificateMismatchError;

  /// No description provided for @tlsConnectionError.
  ///
  /// In en, this message translates to:
  /// **'The secure TLS connection failed. Check phone or network proxy settings and the phone and computer clocks.'**
  String get tlsConnectionError;

  /// No description provided for @copyConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Copy connection error details'**
  String get copyConnectionError;

  /// No description provided for @avatarStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Avatars & Social Profile'**
  String get avatarStudioTitle;

  /// No description provided for @avatarStudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize chat avatars, Cel presets, and your display name'**
  String get avatarStudioSubtitle;

  /// No description provided for @companionAvatarTab.
  ///
  /// In en, this message translates to:
  /// **'Companion'**
  String get companionAvatarTab;

  /// No description provided for @userAvatarTab.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get userAvatarTab;

  /// No description provided for @pickAlbumAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose photo from album'**
  String get pickAlbumAvatar;

  /// No description provided for @resetDefaultAvatar.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get resetDefaultAvatar;

  /// No description provided for @presetAvatarsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cel Academy Presets'**
  String get presetAvatarsTitle;

  /// No description provided for @userNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'My display name'**
  String get userNicknameLabel;

  /// No description provided for @userNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to show “You”'**
  String get userNicknameHint;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get saveProfile;

  /// No description provided for @stickerButton.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get stickerButton;

  /// No description provided for @imageButton.
  ///
  /// In en, this message translates to:
  /// **'Send photo'**
  String get imageButton;

  /// No description provided for @voiceModeButton.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get voiceModeButton;

  /// No description provided for @keyboardModeButton.
  ///
  /// In en, this message translates to:
  /// **'Keyboard input'**
  String get keyboardModeButton;

  /// No description provided for @holdToTalk.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk'**
  String get holdToTalk;

  /// No description provided for @releaseToSend.
  ///
  /// In en, this message translates to:
  /// **'Release to send'**
  String get releaseToSend;

  /// No description provided for @slideUpToCancel.
  ///
  /// In en, this message translates to:
  /// **'Slide up to cancel'**
  String get slideUpToCancel;

  /// No description provided for @releaseToCancel.
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get releaseToCancel;

  /// No description provided for @tapToRecordHint.
  ///
  /// In en, this message translates to:
  /// **'Hold to record · or tap to start/stop'**
  String get tapToRecordHint;

  /// No description provided for @voiceTooShortError.
  ///
  /// In en, this message translates to:
  /// **'Recording was too short. Hold a bit longer to send.'**
  String get voiceTooShortError;

  /// No description provided for @micPermissionError.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is needed to send voice messages.'**
  String get micPermissionError;

  /// No description provided for @micUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Microphone is currently unavailable.'**
  String get micUnavailableError;

  /// No description provided for @invalidMediaError.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected image or media file.'**
  String get invalidMediaError;

  /// No description provided for @mediaPlaybackError.
  ///
  /// In en, this message translates to:
  /// **'This voice clip cannot be played locally.'**
  String get mediaPlaybackError;

  /// No description provided for @mediaUploadError.
  ///
  /// In en, this message translates to:
  /// **'The attachment could not be uploaded. Your message is saved on this phone; retry when the computer is available.'**
  String get mediaUploadError;

  /// No description provided for @mediaDownloadError.
  ///
  /// In en, this message translates to:
  /// **'The message is synced, but its attachment could not be downloaded. Retry when the computer is available.'**
  String get mediaDownloadError;

  /// No description provided for @retryMedia.
  ///
  /// In en, this message translates to:
  /// **'Retry attachments'**
  String get retryMedia;

  /// No description provided for @stickerPackBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Companion Pack'**
  String get stickerPackBuiltIn;

  /// No description provided for @stickerPackCustom.
  ///
  /// In en, this message translates to:
  /// **'My favorites'**
  String get stickerPackCustom;

  /// No description provided for @addCustomSticker.
  ///
  /// In en, this message translates to:
  /// **'Add sticker'**
  String get addCustomSticker;

  /// No description provided for @customStickerTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Label this sticker'**
  String get customStickerTagTitle;

  /// No description provided for @customStickerTagHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Happy, Pat pat, Got it'**
  String get customStickerTagHint;

  /// No description provided for @deleteSticker.
  ///
  /// In en, this message translates to:
  /// **'Remove from my favorites'**
  String get deleteSticker;

  /// No description provided for @noCustomStickers.
  ///
  /// In en, this message translates to:
  /// **'Save images you like, or add a sticker from your gallery. Favorites stay on this phone and can be added offline.'**
  String get noCustomStickers;

  /// No description provided for @replyAction.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get replyAction;

  /// No description provided for @copyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get copyAction;

  /// No description provided for @copiedToast.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToast;

  /// No description provided for @saveAsStickerAction.
  ///
  /// In en, this message translates to:
  /// **'Save as sticker'**
  String get saveAsStickerAction;

  /// No description provided for @savedStickerToast.
  ///
  /// In en, this message translates to:
  /// **'Saved to my sticker favorites'**
  String get savedStickerToast;

  /// No description provided for @cancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get cancelReply;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String replyingTo(String name);

  /// No description provided for @voiceMessageTag.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessageTag;

  /// No description provided for @imageMessageTag.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get imageMessageTag;

  /// No description provided for @stickerMessageTag.
  ///
  /// In en, this message translates to:
  /// **'Sticker'**
  String get stickerMessageTag;

  /// No description provided for @playVoice.
  ///
  /// In en, this message translates to:
  /// **'Play voice'**
  String get playVoice;

  /// No description provided for @stopVoice.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get stopVoice;

  /// No description provided for @quickIcebreakerPat.
  ///
  /// In en, this message translates to:
  /// **'Pat pat'**
  String get quickIcebreakerPat;

  /// No description provided for @quickIcebreakerPeek.
  ///
  /// In en, this message translates to:
  /// **'What are you up to today?'**
  String get quickIcebreakerPeek;

  /// No description provided for @quickIcebreakerTea.
  ///
  /// In en, this message translates to:
  /// **'Let’s take a tea break'**
  String get quickIcebreakerTea;

  /// No description provided for @profileCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Avatars & Social Profile'**
  String get profileCardTitle;

  /// No description provided for @connectionCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Engine Connection'**
  String get connectionCardTitle;

  /// No description provided for @controlCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen & Device Control'**
  String get controlCardTitle;

  /// No description provided for @deleteLocalStickerDescription.
  ///
  /// In en, this message translates to:
  /// **'Removes this phone\'s favorite only. The Bot\'s sticker library and images in past chats are unchanged.'**
  String get deleteLocalStickerDescription;
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
