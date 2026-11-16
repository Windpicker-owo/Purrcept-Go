/// Purrcept Go social companion chat & device interface in Purrcept Cel v0.4 aesthetics.
/// All agent cognition runs on the paired computer; the phone owns durable local state and rich media UX.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'activity.dart';
import 'avatars.dart';
import 'device.dart';
import 'experience.dart';
import 'l10n/app_localizations.dart';
import 'mobile_theme.dart';
import 'onboarding.dart';
import 'pairing.dart';
import 'press_feedback.dart';
import 'stickers.dart';
import 'tokens.dart';
import 'voice_ui.dart';

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

  bool voiceMode = false;
  bool stickerDrawerOpen = false;
  bool cancellingVoice = false;
  Map<String, dynamic>? replyingTo;

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
    final colors = PhoneColors.of(context);
    final largeScale = MediaQuery.textScalerOf(context).scale(14) > 22;

    return AnimatedBuilder(
      animation: device,
      builder: (context, _) {
        final showSocialHeader =
            device.loaded && device.paired && device.setupStep >= 4;
        final companionName = device.experience.name ?? text.companionFallback;

        return Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(
              largeScale ? 86 : (showSocialHeader ? 68 : kToolbarHeight),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  bottom: BorderSide(color: colors.outline, width: 1.5),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Cel.space,
                    vertical: 6,
                  ),
                  child: showSocialHeader
                      ? _buildSocialHeader(
                          context,
                          text,
                          colors,
                          companionName,
                          largeScale,
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.paired ? companionName : 'Purrcept Go',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (device.loaded && device.paired)
                              _connectionPill(context, text, colors),
                          ],
                        ),
                ),
              ),
            ),
          ),
          body: CelAtmosphereBackdrop(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (device.error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Cel.space,
                        Cel.spaceSm,
                        Cel.space,
                        0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: colors.celCard(
                          fill: colors.failedContainer,
                          border: colors.failed,
                          radius: 18,
                          elevated: false,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                errorDescription(text, device.error!),
                                style: TextStyle(
                                  color: colors.failed,
                                  fontWeight: FontWeight.w600,
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
                              if (device.online &&
                                  {
                                    'media_upload_failed',
                                    'media_download_failed',
                                    'media_missing',
                                  }.contains(device.error))
                                TextButton(
                                  onPressed: device.busy
                                      ? null
                                      : () => device.invoke('retry_media'),
                                  child: Text(text.retryMedia),
                                ),
                            ],
                          ),
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
                        ? chat(text, colors, largeScale)
                        : controls(text, colors),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar:
              !device.loaded || !device.paired || device.setupStep < 4
              ? null
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(color: colors.outline, width: 1.5),
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: page,
                    onDestinationSelected: (index) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        page = index;
                        stickerDrawerOpen = false;
                      });
                    },
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        selectedIcon: const Icon(Icons.chat_bubble_rounded),
                        label: text.chat,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.tune_rounded),
                        selectedIcon: const Icon(Icons.phonelink_setup_rounded),
                        label: text.device,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSocialHeader(
    BuildContext context,
    PhoneL10n text,
    PhoneColors colors,
    String companionName,
    bool largeScale,
  ) {
    final exp = device.experience;
    return Row(
      children: [
        if (!largeScale) ...[
          CompanionAvatar(
            isBot: true,
            avatarSource: device.botAvatar,
            phase: exp.phase,
            size: MobileTokens.headerAvatarSize,
            showStatusDot: true,
            online: device.online,
            onTap: () => showAvatarStudioSheet(
              context: context,
              device: device,
              initialTab: 0,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: GestureDetector(
            onTap: () => showAvatarStudioSheet(
              context: context,
              device: device,
              initialTab: 0,
            ),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companionName,
                  style: Theme.of(context).textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!largeScale)
                  Text(
                    activityLabel(exp, text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: exp.working ? colors.active : colors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        _connectionPill(context, text, colors),
        if (!largeScale) ...[
          const SizedBox(width: 8),
          CompanionAvatar(
            isBot: false,
            avatarSource: device.userAvatar,
            fallbackName: device.userName ?? text.you,
            size: 34,
            onTap: () => showAvatarStudioSheet(
              context: context,
              device: device,
              initialTab: 1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _connectionPill(
    BuildContext context,
    PhoneL10n text,
    PhoneColors colors,
  ) {
    final online = device.online;
    final fg = online ? colors.active : colors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: online ? colors.activeContainer : colors.sunken,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: online ? colors.activeSignal : colors.outline,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.5,
            height: 6.5,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            connectionLabel(text),
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String connectionLabel(PhoneL10n text) => switch (device.phase) {
    'online' => text.online,
    'connecting' => text.connecting,
    'reconnecting' => text.reconnecting,
    _ => text.offline,
  };

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
    'voice_too_short' => text.voiceTooShortError,
    'mic_permission_denied' => text.micPermissionError,
    'microphone_unavailable' => text.micUnavailableError,
    'invalid_media' || 'media_too_large' => text.invalidMediaError,
    'media_playback_failed' || 'media_missing' => text.mediaPlaybackError,
    'media_upload_failed' => text.mediaUploadError,
    'media_download_failed' => text.mediaDownloadError,
    'storage_unavailable' => text.storageError,
    'service_unavailable' || 'not_ready' => text.serviceError,
    'not_paired' => text.notPairedError,
    'forget_before_pairing' => text.forgetFirstError,
    'disconnect_before_pairing' => text.disconnectFirstError,
    _ when code.startsWith('pairing_rejected_') => text.pairingRejected,
    _ => text.requestFailed(code),
  };

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

  Map<String, Object?> _withReplyArgs(Map<String, Object?> base) {
    final target = replyingTo;
    if (target == null) return base;
    final sender = target['direction'] == 'incoming'
        ? (device.userName ?? PhoneL10n.of(context).you)
        : (device.experience.name ?? PhoneL10n.of(context).companionFallback);
    final preview = (target['text'] as String? ?? '').trim();
    return {
      ...base,
      'reply_to_id': target['message_id'],
      'reply_sender': sender,
      'reply_preview': preview.length > 60
          ? '${preview.substring(0, 60)}…'
          : preview,
    };
  }

  Future<void> _sendBuiltInSticker(BuiltInSticker sticker) async {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final ok = await device.invoke(
      'send',
      _withReplyArgs({
        'text': sticker.wireText(isZh),
        'kind': 'sticker',
        'sticker_id': sticker.id,
      }),
    );
    if (ok && mounted) {
      setState(() {
        stickerDrawerOpen = false;
        replyingTo = null;
      });
    }
  }

  Future<void> _sendCustomSticker(Map<String, dynamic> custom) async {
    final tag = (custom['tag'] as String? ?? '表情').trim();
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final ok = await device.invoke(
      'send',
      _withReplyArgs({
        'text': isZh ? '[表情：$tag]' : '[Sticker: $tag]',
        'kind': 'sticker',
        'local_path': custom['local_path'],
        'sticker_id': custom['sticker_id'],
        'media_type': custom['media_type'] ?? 'image/png',
      }),
    );
    if (ok && mounted) {
      setState(() {
        stickerDrawerOpen = false;
        replyingTo = null;
      });
    }
  }

  Future<void> _pickAndSendPhoto(PhoneL10n text) async {
    final picked = await device.pickImage('chat_image');
    final path = picked?['local_path'] as String?;
    if (path == null || path.isEmpty || !mounted) return;
    final typedCaption = composer.text.trim();
    final caption = typedCaption.isNotEmpty
        ? typedCaption
        : '[${text.imageMessageTag}]';
    final ok = await device.invoke(
      'send',
      _withReplyArgs({
        'text': caption,
        'kind': 'image',
        'local_path': path,
        'media_type': picked?['media_type'] ?? 'image/jpeg',
      }),
    );
    if (ok && mounted) {
      if (typedCaption.isNotEmpty) composer.clear();
      setState(() => replyingTo = null);
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _sendRecordedVoice(Map<String, dynamic> recorded) async {
    final text = PhoneL10n.of(context);
    final durationMs = (recorded['duration_ms'] as num?)?.toInt() ?? 1000;
    final secs = ((durationMs / 1000).round()).clamp(1, 600);
    final ok = await device.invoke(
      'send',
      _withReplyArgs({
        'text': '[${text.voiceMessageTag} $secs″]',
        'kind': 'voice',
        'local_path': recorded['local_path'],
        'media_type': recorded['media_type'] ?? 'audio/wav',
        'duration_ms': durationMs,
        'waveform': recorded['waveform'],
      }),
    );
    if (ok && mounted) {
      setState(() => replyingTo = null);
    }
  }

  Widget chat(PhoneL10n text, PhoneColors colors, bool largeScale) {
    final messages = device.messages;
    final experience = device.experience;
    final arrivals = <String>{};
    for (final message in messages) {
      final id = message['message_id'] as String? ?? '';
      if (hasOpenedChat && !seenMessages.contains(id)) arrivals.add(id);
      seenMessages.add(id);
    }
    hasOpenedChat = true;

    final offlineNotice = Text(
      device.onlineWanted ? text.connectingHint : text.offlineHint,
      style: TextStyle(color: colors.inkSecondary),
    );
    final reconnectButton = FilledButton(
      onPressed: device.busy ? null : () => device.invoke('online'),
      child: Text(device.onlineWanted ? text.reconnect : text.connect),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MobileTokens.contentMax),
        child: Column(
          children: [
            // Connection status remains in the header while composing; leave room for the drawer.
            if (!device.online &&
                !stickerDrawerOpen &&
                MediaQuery.viewInsetsOf(context).bottom == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Cel.space,
                  Cel.spaceSm,
                  Cel.space,
                  0,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: colors.celCard(
                    notebook: true,
                    radius: 18,
                    elevated: false,
                  ),
                  child: largeScale
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            offlineNotice,
                            const SizedBox(height: 8),
                            reconnectButton,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: offlineNotice),
                            const SizedBox(width: Cel.spaceSm),
                            reconnectButton,
                          ],
                        ),
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(Cel.space * 1.25),
                        child: CompanionPresence(
                          experience: experience,
                          hero: true,
                          footer: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              ActionChip(
                                avatar: const Icon(
                                  Icons.pets_rounded,
                                  size: 16,
                                ),
                                label: Text(text.quickIcebreakerPat),
                                onPressed: () =>
                                    _sendBuiltInSticker(kBuiltInStickers[1]),
                              ),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.chat_outlined,
                                  size: 16,
                                ),
                                label: Text(text.quickIcebreakerPeek),
                                onPressed: () => device.invoke('send', {
                                  'text': text.quickIcebreakerPeek,
                                }),
                              ),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.emoji_food_beverage_outlined,
                                  size: 16,
                                ),
                                label: Text(text.quickIcebreakerTea),
                                onPressed: () =>
                                    _sendBuiltInSticker(kBuiltInStickers[9]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        if (stickerDrawerOpen) {
                          setState(() => stickerDrawerOpen = false);
                        }
                      },
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(
                          Cel.spaceSm,
                          Cel.space,
                          Cel.spaceSm,
                          Cel.spaceXs,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msgIndex = messages.length - 1 - index;
                          final message = messages[msgIndex];
                          final prev = msgIndex > 0
                              ? messages[msgIndex - 1]
                              : null;
                          final timeHeader = _timeDividerLabel(prev, message);

                          return MessageArrival(
                            key: ValueKey(
                              '${message['direction']}:${message['message_id']}',
                            ),
                            animate: arrivals.contains(message['message_id']),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (timeHeader != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 12,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.sunken,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: colors.outlineSubtle,
                                        ),
                                      ),
                                      child: Text(
                                        timeHeader,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.muted,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                messageBubble(
                                  message,
                                  messages,
                                  experience,
                                  text,
                                  largeScale,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
            if (messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Cel.spaceSm),
                child: CompanionPresence(experience: experience),
              ),
            if (device.isRecordingVoice)
              VoiceRecordingHud(
                startedAtMs: device.recordingStartedAtMs,
                level: device.recordingLevel,
                cancelling: cancellingVoice,
              ),
            if (replyingTo != null) _buildReplyBanner(text, colors),
            _buildComposerBar(text, colors),
            if (stickerDrawerOpen)
              StickerDrawerPanel(
                device: device,
                onSendBuiltIn: _sendBuiltInSticker,
                onSendCustom: _sendCustomSticker,
              ),
          ],
        ),
      ),
    );
  }

  String? _timeDividerLabel(
    Map<String, dynamic>? prev,
    Map<String, dynamic> curr,
  ) {
    final raw = curr['occurred_at'] as String?;
    if (raw == null) return null;
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return null;
    if (prev != null) {
      final prevRaw = prev['occurred_at'] as String?;
      final prevDt = prevRaw != null
          ? DateTime.tryParse(prevRaw)?.toLocal()
          : null;
      if (prevDt != null && dt.difference(prevDt).inMinutes.abs() < 5) {
        return null;
      }
    }
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '$hh:$mm';
    }
    return '${dt.month}/${dt.day} $hh:$mm';
  }

  Widget _buildReplyBanner(PhoneL10n text, PhoneColors colors) {
    final target = replyingTo!;
    final sender = target['direction'] == 'incoming'
        ? (device.userName ?? text.you)
        : (device.experience.name ?? text.companionFallback);
    final snippet = (target['text'] as String? ?? '').trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(Cel.spaceSm, 6, Cel.spaceSm, 0),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlinePaper, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: colors.blushSignal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text.replyingTo(sender),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.brand,
                  ),
                ),
                Text(
                  snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: text.cancelReply,
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => replyingTo = null),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerBar(PhoneL10n text, PhoneColors colors) {
    // Keep text and attachments on separate rows so narrow screens retain room to type.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Cel.spaceSm,
        Cel.spaceXs,
        Cel.spaceSm,
        Cel.spaceSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: voiceMode
                    ? VoiceHoldToTalkBar(
                        device: device,
                        onCancelChanged: (val) =>
                            setState(() => cancellingVoice = val),
                        onVoiceRecorded: _sendRecordedVoice,
                      )
                    : TextField(
                        key: const ValueKey("chat-composer"),
                        controller: composer,
                        minLines: 1,
                        maxLines: 5,
                        onTap: () {
                          if (stickerDrawerOpen) {
                            setState(() => stickerDrawerOpen = false);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: text.messageHint,
                          hintMaxLines: 1,
                        ),
                      ),
              ),
              const SizedBox(width: 6),
              if (!voiceMode)
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
                          backgroundColor: canSend
                              ? colors.brandFill
                              : colors.sunken,
                          foregroundColor: canSend
                              ? colors.onBrand
                              : colors.muted,
                          minimumSize: const Size(46, 46),
                          side: BorderSide(
                            color: canSend ? Cel.brandPressed : colors.outline,
                            width: 1.5,
                          ),
                        ),
                        onPressed: !canSend
                            ? null
                            : () async {
                                final draft = composer.text;
                                // Preserve exact {'text': draft} map when sending plain unquoted text.
                                final payload = replyingTo == null
                                    ? <String, Object?>{'text': draft}
                                    : _withReplyArgs({'text': draft});
                                if (draft.trim().isNotEmpty &&
                                    await device.invoke('send', payload) &&
                                    mounted &&
                                    composer.text == draft) {
                                  composer.clear();
                                  if (replyingTo != null) {
                                    setState(() => replyingTo = null);
                                  }
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
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              IconButton(
                tooltip: voiceMode
                    ? text.keyboardModeButton
                    : text.voiceModeButton,
                style: IconButton.styleFrom(
                  backgroundColor: colors.surface,
                  side: BorderSide(color: colors.outline, width: 1.4),
                  minimumSize: const Size(42, 42),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    voiceMode = !voiceMode;
                    if (voiceMode) stickerDrawerOpen = false;
                  });
                },
                icon: Icon(
                  voiceMode ? Icons.keyboard_rounded : Icons.mic_none_rounded,
                  size: 20,
                  color: colors.ink,
                ),
              ),
              IconButton(
                tooltip: text.stickerButton,
                style: IconButton.styleFrom(
                  backgroundColor: stickerDrawerOpen
                      ? colors.blushContainer
                      : colors.surface,
                  side: BorderSide(
                    color: stickerDrawerOpen
                        ? colors.blushSignal
                        : colors.outline,
                    width: 1.4,
                  ),
                  minimumSize: const Size(42, 42),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  FocusScope.of(context).unfocus();
                  setState(() {
                    stickerDrawerOpen = !stickerDrawerOpen;
                    if (stickerDrawerOpen) voiceMode = false;
                  });
                },
                icon: Icon(
                  Icons.emoji_emotions_outlined,
                  size: 20,
                  color: stickerDrawerOpen ? Cel.onBlushContainer : colors.ink,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: text.imageButton,
                style: IconButton.styleFrom(
                  backgroundColor: colors.surface,
                  side: BorderSide(color: colors.outline, width: 1.4),
                  minimumSize: const Size(42, 42),
                ),
                onPressed: device.busy ? null : () => _pickAndSendPhoto(text),
                icon: Icon(Icons.image_outlined, size: 20, color: colors.ink),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget messageBubble(
    Map<String, dynamic> message,
    List<Map<String, dynamic>> allMessages,
    SubjectExperience experience,
    PhoneL10n text,
    bool largeScale,
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
    final statusColor = phase == MessagePhase.failed
        ? colors.failed
        : phase == MessagePhase.saved || phase == MessagePhase.waiting
        ? colors.waiting
        : colors.muted;

    final senderName = fromUser
        ? (device.userName ?? text.you)
        : (experience.name ?? text.companionFallback);

    final rawText = message['text'] as String? ?? '';
    final explicitKind = message['kind'] as String?;
    final stickerId =
        (message['sticker_id'] as String?) ?? matchStickerFromText(rawText)?.id;
    final isSticker = explicitKind == 'sticker' || stickerId != null;
    final isVoice = explicitKind == 'voice';
    final isImage = explicitKind == 'image';
    final localPath = message['local_path'] as String?;

    // Resolve optional quote-reply preview
    final replyToId = message['reply_to_id'] as String?;
    String? replyPreview = message['reply_preview'] as String?;
    String? replySender = message['reply_sender'] as String?;
    if (replyToId != null && (replyPreview == null || replyPreview.isEmpty)) {
      for (final candidate in allMessages) {
        if (candidate['message_id'] == replyToId) {
          replyPreview = candidate['text'] as String?;
          replySender = candidate['direction'] == 'incoming'
              ? (device.userName ?? text.you)
              : (experience.name ?? text.companionFallback);
          break;
        }
      }
    }

    final Widget bodyContent;
    if (isSticker) {
      bodyContent = Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: CelStickerView(
          stickerId: stickerId,
          localPath: localPath,
          size: MobileTokens.stickerSize,
        ),
      );
    } else if (isVoice) {
      bodyContent = VoiceMessageBubble(
        message: message,
        fromUser: fromUser,
        device: device,
      );
    } else if (isImage && localPath != null && File(localPath).existsSync()) {
      final showCaption =
          rawText.trim().isNotEmpty &&
          rawText.trim() != '[${text.imageMessageTag}]' &&
          rawText.trim() != '[图片]' &&
          rawText.trim() != '[Photo]';
      bodyContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 240),
              child: Image.file(File(localPath), fit: BoxFit.cover),
            ),
          ),
          if (showCaption) ...[
            const SizedBox(height: 6),
            SelectableText(
              rawText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      );
    } else {
      bodyContent = SelectableText(
        rawText,
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }

    final bubbleSurface = isSticker
        ? Column(
            crossAxisAlignment: fromUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (replyPreview != null && replyPreview.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlinePaper),
                  ),
                  child: Text(
                    '${replySender ?? ''}: $replyPreview',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: colors.muted),
                  ),
                ),
              bodyContent,
            ],
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: colors.celBubble(fromUser: fromUser),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (replyPreview != null && replyPreview.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: fromUser
                          ? colors.surface.withValues(alpha: 0.65)
                          : colors.sunken,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: colors.brandSignal, width: 3),
                      ),
                    ),
                    child: Text(
                      replySender != null && replySender.isNotEmpty
                          ? '$replySender: $replyPreview'
                          : replyPreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.inkSecondary,
                      ),
                    ),
                  ),
                ],
                bodyContent,
              ],
            ),
          );

    final statusLine = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: fromUser
            ? () => showMessageProgress(message, experience, text)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
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
                        color: statusColor,
                        fontSize: MobileTokens.labelSize - 0.5,
                      ),
                    ),
                  ),
                  if (fromUser) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline_rounded,
                      size: MobileTokens.labelSize,
                      color: statusColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final avatarSize = largeScale ? 30.0 : MobileTokens.chatAvatarSize;
    final avatarWidget = CompanionAvatar(
      isBot: !fromUser,
      avatarSource: fromUser ? device.userAvatar : device.botAvatar,
      fallbackName: senderName,
      phase: experience.phase,
      size: avatarSize,
      onTap: () => showAvatarStudioSheet(
        context: context,
        device: device,
        initialTab: fromUser ? 1 : 0,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onLongPress: () => _showMessageActions(message, experience, text),
        child: Row(
          mainAxisAlignment: fromUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!fromUser) ...[avatarWidget, const SizedBox(width: 8)],
            Flexible(
              child: Column(
                crossAxisAlignment: fromUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 3,
                      left: 2,
                      right: 2,
                    ),
                    child: Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  bubbleSurface,
                  statusLine,
                ],
              ),
            ),
            if (fromUser) ...[const SizedBox(width: 8), avatarWidget],
          ],
        ),
      ),
    );
  }

  Future<void> _showMessageActions(
    Map<String, dynamic> message,
    SubjectExperience experience,
    PhoneL10n text,
  ) {
    final fromUser = message['direction'] == 'incoming';
    final rawText = message['text'] as String? ?? '';
    final localPath = message['local_path'] as String?;
    final canSaveSticker =
        const {'image', 'sticker'}.contains(message['kind']) &&
        localPath != null &&
        File(localPath).existsSync();

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: Text(text.replyAction),
              onTap: () {
                Navigator.pop(sheetCtx);
                setState(() => replyingTo = message);
              },
            ),
            if (rawText.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(text.copyAction),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: rawText));
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(text.copiedToast)));
                },
              ),
            if (canSaveSticker)
              ListTile(
                leading: const Icon(Icons.star_border_rounded),
                title: Text(text.saveAsStickerAction),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final tag = await requestStickerTag(context);
                  if (tag == null || !mounted) return;
                  final saved = await device.invoke('add_sticker', {
                    'local_path': localPath,
                    'media_type': message['media_type'] ?? 'image/png',
                    'tag': tag,
                  });
                  if (saved && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(text.savedStickerToast)),
                    );
                  }
                },
              ),
            if (fromUser)
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(text.messageDetails),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showMessageProgress(message, experience, text);
                },
              ),
          ],
        ),
      ),
    );
  }

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

  Widget controls(PhoneL10n text, PhoneColors colors) {
    final companionName = device.experience.name ?? text.companionFallback;
    return ListView(
      padding: const EdgeInsets.all(Cel.space),
      children: [
        // Card 1: Avatars & Social Profile Studio
        Container(
          padding: const EdgeInsets.all(Cel.space),
          decoration: colors.celCard(notebook: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.profileCardTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                text.avatarStudioSubtitle,
                style: TextStyle(
                  fontSize: MobileTokens.labelSize,
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: Cel.spaceSm),
              Wrap(
                spacing: Cel.space,
                runSpacing: Cel.spaceSm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CompanionAvatar(
                        isBot: true,
                        avatarSource: device.botAvatar,
                        phase: device.experience.phase,
                        size: 48,
                        onTap: () => showAvatarStudioSheet(
                          context: context,
                          device: device,
                          initialTab: 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          companionName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CompanionAvatar(
                        isBot: false,
                        avatarSource: device.userAvatar,
                        fallbackName: device.userName ?? text.you,
                        size: 48,
                        onTap: () => showAvatarStudioSheet(
                          context: context,
                          device: device,
                          initialTab: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          device.userName ?? text.you,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Cel.spaceSm),
              OutlinedButton.icon(
                onPressed: () =>
                    showAvatarStudioSheet(context: context, device: device),
                icon: const Icon(Icons.palette_outlined, size: 18),
                label: Text(text.avatarStudioTitle),
              ),
            ],
          ),
        ),
        const SizedBox(height: Cel.space),

        // Card 2: Engine Connection & Notifications
        PhoneCard(
          padding: const EdgeInsets.symmetric(vertical: Cel.spaceXs),
          decoration: colors.celCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Cel.space,
                  Cel.spaceSm,
                  Cel.space,
                  0,
                ),
                child: Text(
                  text.connectionCardTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ListTile(
                title: Text(text.host),
                subtitle: Text(device.snapshot['host'] as String? ?? ''),
              ),
              SwitchListTile(
                title: Text(text.stayOnline),
                subtitle: Text(text.onlineDescription),
                value: device.onlineWanted,
                onChanged: (value) =>
                    device.invoke(value ? 'online' : 'offline'),
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
            ],
          ),
        ),
        const SizedBox(height: Cel.space),

        // Card 3: Screen & Device Control
        PhoneCard(
          padding: const EdgeInsets.symmetric(vertical: Cel.spaceXs),
          decoration: colors.celCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Cel.space,
                  Cel.spaceSm,
                  Cel.space,
                  0,
                ),
                child: Text(
                  text.controlCardTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SwitchListTile(
                title: Text(text.allowControl),
                subtitle: Text(text.controlDescription),
                value: device.snapshot['control_allowed'] == true,
                onChanged: (value) =>
                    device.invoke('control', {'allowed': value}),
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
            ],
          ),
        ),
        const SizedBox(height: Cel.space),

        // Card 4: Pairing Reset & Open-Source Licenses
        PhoneCard(
          padding: const EdgeInsets.all(Cel.space),
          decoration: colors.celCard(elevated: false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: Cel.spaceXs),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(text.openSourceLicenses),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Purrcept Go',
                ),
              ),
              Text(
                text.about,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: MobileTokens.labelSize,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
