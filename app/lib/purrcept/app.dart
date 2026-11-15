/// The phone's chat and device controls use native durable state, never an embedded agent runtime.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device.dart';
import 'l10n/app_localizations.dart';
import 'pairing.dart';
import 'tokens.dart';

class PurrceptApp extends StatelessWidget {
  const PurrceptApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Purrcept Go',
    debugShowCheckedModeBanner: false,
    localizationsDelegates: PhoneL10n.localizationsDelegates,
    supportedLocales: PhoneL10n.supportedLocales,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: Cel.brand,
        onPrimary: Cel.onBrand,
        surface: Cel.surface,
        onSurface: Cel.ink,
        error: Cel.failed,
      ),
      scaffoldBackgroundColor: Cel.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: Cel.canvas,
        foregroundColor: Cel.ink,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Cel.sunken,
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(Cel.radius),
        ),
      ),
    ),
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
          title: const Text('Purrcept'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Cel.space),
              child: Center(
                child: Text(
                  connectionLabel(text),
                  style: TextStyle(
                    color: device.online ? Cel.active : Cel.muted,
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
                    child: Text(
                      errorDescription(text, device.error!),
                      style: const TextStyle(color: Cel.failed),
                    ),
                  ),
                ),
              Expanded(
                child: !device.paired
                    ? pairing(text)
                    : page == 0
                    ? chat(text)
                    : controls(text),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: page,
          onDestinationSelected: (index) => setState(() => page = index),
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

  Widget pairing(PhoneL10n text) => Center(
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Cel.contentMax),
        child: Padding(
          padding: const EdgeInsets.all(Cel.space * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text.pairTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: Cel.space),
              Text(text.pairDescription),
              const SizedBox(height: Cel.space * 2),
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
                  Row(
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
                      const Spacer(),
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
          ),
        ),
      ),
    ),
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
                style: const TextStyle(color: Cel.muted),
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

  Widget chat(PhoneL10n text) {
    final messages = device.messages;
    return Column(
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
                FilledButton(
                  onPressed: device.busy ? null : () => device.invoke('online'),
                  child: Text(
                    device.onlineWanted ? text.reconnect : text.connect,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: messages.isEmpty
              ? Center(child: Text(text.emptyChat))
              : ListView.builder(
                  // Reverse order starts at the newest bubble without forcing a reader back down
                  // whenever an older message is being inspected.
                  reverse: true,
                  padding: const EdgeInsets.all(Cel.space),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final fromUser = message['direction'] == 'incoming';
                    return Align(
                      alignment: fromUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: Cel.contentMax,
                        ),
                        margin: const EdgeInsets.only(bottom: Cel.space),
                        padding: const EdgeInsets.all(Cel.space),
                        decoration: BoxDecoration(
                          color: fromUser ? Cel.sunken : Cel.surface,
                          borderRadius: BorderRadius.circular(Cel.radius),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fromUser ? text.you : 'Purrcept',
                              style: const TextStyle(color: Cel.muted),
                            ),
                            const SizedBox(height: Cel.space / 2),
                            SelectableText(message['text'] as String? ?? ''),
                            const SizedBox(height: Cel.space / 2),
                            Text(
                              switch (message['delivery_state']) {
                                'pending' => text.pending,
                                'accepted' => text.acceptedPending,
                                _ =>
                                  fromUser
                                      ? text.engineAccepted
                                      : text.receivedOnPhone,
                              },
                              style: TextStyle(
                                color: message['delivery_state'] == 'pending'
                                    ? Cel.waiting
                                    : Cel.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
              const SizedBox(width: Cel.space),
              IconButton.filled(
                tooltip: text.send,
                onPressed: device.busy
                    ? null
                    : () async {
                        final value = composer.text;
                        if (value.trim().isNotEmpty &&
                            await device.invoke('send', {'text': value}) &&
                            mounted &&
                            composer.text == value) {
                          composer.clear();
                        }
                      },
                icon: const Icon(Icons.arrow_upward),
              ),
            ],
          ),
        ),
      ],
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
      Text(text.about, style: const TextStyle(color: Cel.muted)),
    ],
  );
}
