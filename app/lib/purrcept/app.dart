/// The phone's chat and device controls use native durable state, never an embedded agent runtime.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device.dart';
import 'activity.dart';
import 'experience.dart';
import 'l10n/app_localizations.dart';
import 'mobile_theme.dart';
import 'pairing.dart';
import 'onboarding.dart';
import 'tokens.dart';
import 'press_feedback.dart';

class PurrceptApp extends StatelessWidget {
  const PurrceptApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Purrcept Go',
    debugShowCheckedModeBanner: false,
    localizationsDelegates: PhoneL10n.localizationsDelegates,
    supportedLocales: PhoneL10n.supportedLocales,
    theme: phoneTheme(Brightness.light),
    darkTheme: phoneTheme(Brightness.dark),
    home: const DeviceHome(),
  );
}

class DeviceHome extends StatefulWidget {
  const DeviceHome({super.key});
  @override
  State<DeviceHome> createState() => _DeviceHomeState();
}

class _DeviceHomeState extends State<DeviceHome> with WidgetsBindingObserver {
  final device = DeviceController();
  final composer = TextEditingController();
  final invitation = TextEditingController();
  int page = 0;
  final seenMessages = <String>{};
  bool hasOpenedChat = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    device.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) device.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    device.dispose();
    composer.dispose();
    invitation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = PhoneL10n.of(context);
    return AnimatedBuilder(
      animation: device,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          toolbarHeight:
              MediaQuery.textScalerOf(context).scale(MobileTokens.titleSize) +
                      Cel.space >
                  kToolbarHeight
              ? MediaQuery.textScalerOf(context).scale(MobileTokens.titleSize) +
                    Cel.space
              : kToolbarHeight,
          title: Text(
            device.paired
                ? device.experience.name ?? text.companionFallback
                : 'Purrcept Go',
            style: Theme.of(context).textTheme.headlineMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (device.loaded && device.paired)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Cel.space),
                child: Center(
                  child: Text(
                    connectionLabel(text),
                    style: TextStyle(
                      color: device.online
                          ? PhoneColors.of(context).active
                          : PhoneColors.of(context).muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (device.error != null)
                Padding(
                  padding: const EdgeInsets.all(Cel.space),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          errorDescription(text, device.error!),
                          style: TextStyle(
                            color: PhoneColors.of(context).failed,
                          ),
                        ),
                        if (device.requestDiagnostics != null)
                          TextButton(
                            onPressed: () => Clipboard.setData(
                              ClipboardData(
                                text:
                                    '${device.error}\n${device.requestDiagnostics}',
                              ),
                            ),
                            child: Text(text.copyConnectionError),
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: !device.loaded
                    ? Center(
                        child: device.error == null
                            ? const CircularProgressIndicator()
                            : FilledButton(
                                onPressed: device.refresh,
                                child: Text(text.setupRetry),
                              ),
                      )
                    : !device.paired || device.setupStep < 4
                    ? PhoneSetup(device: device, pairing: pairing(text))
                    : page == 0
                    ? chat(text)
                    : controls(text),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
            !device.loaded || !device.paired || device.setupStep < 4
            ? null
            : NavigationBar(
                selectedIndex: page,
                onDestinationSelected: (index) {
                  HapticFeedback.selectionClick();
                  setState(() => page = index);
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: text.chat,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.phone_android),
                    label: text.device,
                  ),
                ],
              ),
      ),
    );
  }

  /// Connection intent remains distinct from transport availability during automatic reconnect.
  String connectionLabel(PhoneL10n text) => switch (device.phase) {
    'online' => text.online,
    'connecting' => text.connecting,
    'reconnecting' => text.reconnecting,
    _ => text.offline,
  };

  /// Known failures provide a recovery step; unknown codes stay available for diagnosis.
  String errorDescription(PhoneL10n text, String code) => switch (code) {
    'connection_lost' ||
    'connection_closed' ||
    'network_error' => text.networkError,
    'pairing_network_error' => text.pairingNetworkError,
    'network_timeout' => text.networkTimeoutError,
    'computer_unreachable' => text.computerUnreachableError,
    'computer_not_found' => text.computerNotFoundError,
    'network_permission_denied' => text.networkPermissionError,
    'certificate_date_invalid' => text.certificateDateError,
    'certificate_mismatch' => text.certificateMismatchError,
    'tls_connection_failed' => text.tlsConnectionError,
    'authentication_rejected' => text.authenticationError,
    'invalid_protocol' ||
    'unsupported_protocol' ||
    'protocol_error' => text.protocolError,
    'invalid_payload' || 'invalid_host' => text.invitationError,
    'camera_permission_denied' => text.cameraPermissionError,
    'scan_in_progress' => text.scanning,
    'message_too_large' => text.messageTooLarge,
    'invalid_message' => text.invalidMessage,
    'storage_unavailable' => text.storageError,
    'service_unavailable' || 'not_ready' => text.serviceError,
    'not_paired' => text.notPairedError,
    'forget_before_pairing' => text.forgetFirstError,
    'disconnect_before_pairing' => text.disconnectFirstError,
    _ when code.startsWith('pairing_rejected_') => text.pairingRejected,
    _ => text.requestFailed(code),
  };

  /// Camera and manual entry share the same review boundary, inside the setup's scroll surface.
  Widget pairing(PhoneL10n text) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: device.busy
            ? null
            : () async {
                final raw = await device.scanInvitation();
                if (raw != null && mounted) await reviewInvitation(raw);
              },
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(text.scanPair),
      ),
      const SizedBox(height: Cel.space),
      Text(text.scanDescription),
      const SizedBox(height: Cel.space),
      ExpansionTile(
        title: Text(text.manualPairing),
        tilePadding: EdgeInsets.zero,
        children: [
          TextField(
            controller: invitation,
            maxLines: 5,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: text.invitation),
          ),
          const SizedBox(height: Cel.space),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: Cel.space,
            children: [
              TextButton.icon(
                onPressed: device.busy
                    ? null
                    : () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (mounted) invitation.text = data?.text ?? '';
                      },
                icon: const Icon(Icons.content_paste),
                label: Text(text.pasteInvitation),
              ),
              FilledButton(
                onPressed: device.busy
                    ? null
                    : () => reviewInvitation(invitation.text),
                child: Text(text.pair),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  /// Review an untrusted scan or clipboard payload before pairing. Only successful native admission
  /// starts the user-requested online service; neither path requests screen-control permission.
  Future<void> reviewInvitation(String raw) async {
    final text = PhoneL10n.of(context);
    final PairingInvitation parsed;
    try {
      parsed = PairingInvitation.parse(raw);
    } on FormatException {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(text.invitationError)));
      return;
    }
    FocusScope.of(context).unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.confirmPairing),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text.confirmHost(parsed.host)),
              const SizedBox(height: Cel.space),
              Text(text.verifyComputer),
              const SizedBox(height: Cel.space),
              Text(text.certificateFingerprint),
              SelectableText(
                parsed.fingerprint,
                style: TextStyle(color: PhoneColors.of(context).muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(text.pairAndConnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final paired = await device.invoke('pair', {
      'invitation': parsed.raw,
      'name': 'Purrcept Android',
    });
    if (paired && mounted) {
      invitation.clear();
      await device.invoke('online');
    }
  }

  /// Conversation stays readable on wide screens, while the live body remains beside the composer.
  Widget chat(PhoneL10n text) {
    final messages = device.messages;
    final experience = device.experience;
    final arrivals = <String>{};
    for (final message in messages) {
      final id = message['message_id'] as String? ?? '';
      if (hasOpenedChat && !seenMessages.contains(id)) arrivals.add(id);
      seenMessages.add(id);
    }
    hasOpenedChat = true;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MobileTokens.contentMax),
        child: Column(
          children: [
            if (!device.online)
              Padding(
                padding: const EdgeInsets.all(Cel.space),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.onlineWanted
                            ? text.connectingHint
                            : text.offlineHint,
                      ),
                    ),
                    const SizedBox(width: Cel.space),
                    FilledButton(
                      onPressed: device.busy
                          ? null
                          : () => device.invoke('online'),
                      child: Text(
                        device.onlineWanted ? text.reconnect : text.connect,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(Cel.space * 1.5),
                          child: CompanionPresence(
                            experience: experience,
                            hero: true,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(Cel.space),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[messages.length - 1 - index];
                        return MessageArrival(
                          key: ValueKey(
                            '${message['direction']}:${message['message_id']}',
                          ),
                          animate: arrivals.contains(message['message_id']),
                          child: messageBubble(message, experience, text),
                        );
                      },
                    ),
            ),
            if (messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Cel.space),
                child: CompanionPresence(experience: experience),
              ),
            Padding(
              padding: const EdgeInsets.all(Cel.space),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: composer,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(hintText: text.messageHint),
                    ),
                  ),
                  const SizedBox(width: Cel.space / 2),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: composer,
                    builder: (context, value, _) {
                      final canSend =
                          !device.busy && value.text.trim().isNotEmpty;
                      return PressFeedback(
                        enabled: canSend,
                        child: IconButton.filled(
                          tooltip: text.send,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(52, 52),
                          ),
                          onPressed: !canSend
                              ? null
                              : () async {
                                  final value = composer.text;
                                  if (value.trim().isNotEmpty &&
                                      await device.invoke('send', {
                                        'text': value,
                                      }) &&
                                      mounted &&
                                      composer.text == value) {
                                    composer.clear();
                                    HapticFeedback.lightImpact();
                                  }
                                },
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Stage feedback belongs to its own bubble. Completion is never rendered as an implied reply.
  Widget messageBubble(
    Map<String, dynamic> message,
    SubjectExperience experience,
    PhoneL10n text,
  ) {
    final colors = PhoneColors.of(context);
    final fromUser = message['direction'] == 'incoming';
    final phase = messagePhase(message, experience);
    final label = !fromUser
        ? text.receivedOnPhone
        : message['delivery_state'] == 'accepted' &&
              message['processing'] == null
        ? text.acceptedPending
        : messageLabel(phase, text);
    final color = phase == MessagePhase.failed
        ? colors.failed
        : phase == MessagePhase.saved || phase == MessagePhase.waiting
        ? colors.waiting
        : colors.muted;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: MobileTokens.contentMax),
        margin: const EdgeInsets.only(bottom: Cel.space),
        padding: const EdgeInsets.all(Cel.space),
        decoration: BoxDecoration(
          color: fromUser ? colors.hero : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(MobileTokens.bubbleRadius),
            topRight: const Radius.circular(MobileTokens.bubbleRadius),
            bottomLeft: Radius.circular(
              fromUser ? MobileTokens.bubbleRadius : Cel.space / 2,
            ),
            bottomRight: Radius.circular(
              fromUser ? Cel.space / 2 : MobileTokens.bubbleRadius,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fromUser ? text.you : experience.name ?? text.companionFallback,
              style: TextStyle(
                color: colors.muted,
                fontSize: MobileTokens.labelSize,
              ),
            ),
            const SizedBox(height: Cel.space / 2),
            SelectableText(
              message['text'] as String? ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: Cel.space / 2),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(Cel.space / 2),
                onTap: fromUser
                    ? () => showMessageProgress(message, experience, text)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Cel.space / 2),
                  child: Semantics(
                    button: fromUser,
                    label: fromUser ? text.messageDetails : null,
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : MobileTokens.effects,
                      child: Row(
                        key: ValueKey(label),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: color,
                                fontSize: MobileTokens.labelSize,
                              ),
                            ),
                          ),
                          if (fromUser) ...[
                            const SizedBox(width: Cel.space / 2),
                            Icon(
                              Icons.info_outline_rounded,
                              size: MobileTokens.labelSize,
                              color: color,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Freeze this observation for inspection; a short action is explained by its recorded receipt,
  /// without keeping the live mascot artificially busy after execution has ended.
  Future<void> showMessageProgress(
    Map<String, dynamic> message,
    SubjectExperience experience,
    PhoneL10n text,
  ) {
    final raw = message['processing'];
    final action = raw is Map ? raw['last_action'] : null;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(Cel.space * 1.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.messageDetails,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: Cel.space),
                Text(messageLabel(messagePhase(message, experience), text)),
                if (messagePhase(message, experience) ==
                    MessagePhase.unavailable) ...[
                  const SizedBox(height: Cel.space),
                  Text(text.messageProgressUnavailableDetail),
                ],
                const SizedBox(height: Cel.space),
                if (action is Map) ...[
                  Text(
                    text.recentAction,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Cel.space / 2),
                  Text(actionName(action['path'] as String?, text)),
                  Text(receiptLabel(action['state'] as String?, text)),
                  const SizedBox(height: Cel.space),
                  Text(text.receiptExplanation),
                ] else
                  Text(text.noAssociatedAction),
                const SizedBox(height: Cel.space),
                Text(text.statusNotReply),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget controls(PhoneL10n text) => ListView(
    padding: const EdgeInsets.all(Cel.space),
    children: [
      ListTile(
        title: Text(text.host),
        subtitle: Text(device.snapshot['host'] as String? ?? ''),
      ),
      SwitchListTile(
        title: Text(text.stayOnline),
        subtitle: Text(text.onlineDescription),
        value: device.onlineWanted,
        onChanged: (value) => device.invoke(value ? 'online' : 'offline'),
      ),
      ListTile(
        title: Text(text.setupNotifications),
        subtitle: Text(
          device.snapshot['notifications_enabled'] == true
              ? text.enabled
              : text.disabled,
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => device.invoke('notifications'),
      ),
      SwitchListTile(
        title: Text(text.allowControl),
        subtitle: Text(text.controlDescription),
        value: device.snapshot['control_allowed'] == true,
        onChanged: (value) => device.invoke('control', {'allowed': value}),
      ),
      ListTile(
        title: Text(text.accessibility),
        subtitle: Text(
          device.snapshot['accessibility'] == true
              ? text.enabled
              : text.disabled,
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => device.invoke('accessibility'),
      ),
      ListTile(
        title: Text(text.controlSession),
        subtitle: Text(
          device.snapshot['control_connected'] == true
              ? text.connected
              : text.notConnected,
        ),
      ),
      const SizedBox(height: Cel.space),
      OutlinedButton(
        onPressed: device.busy
            ? null
            : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(text.forget),
                    content: Text(text.forgetDescription),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(text.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(text.forget),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await device.invoke('forget');
              },
        child: Text(text.forget),
      ),
      const SizedBox(height: Cel.space),
      ListTile(
        title: Text(text.openSourceLicenses),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            showLicensePage(context: context, applicationName: 'Purrcept Go'),
      ),
      Text(text.about, style: TextStyle(color: PhoneColors.of(context).muted)),
    ],
  );
}
