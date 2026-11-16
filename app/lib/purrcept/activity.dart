/// One live status surface joins a subject's public identity, explicit stage and current action.
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'experience.dart';
import 'l10n/app_localizations.dart';
import 'mascot.dart';
import 'mobile_theme.dart';
import 'tokens.dart';

/// Keep business wording beside the semantic mapping so the mascot can never become the only signal.
String activityLabel(SubjectExperience experience, PhoneL10n text) =>
    switch (experience.phase) {
      CompanionPhase.offline => text.activityOffline,
      CompanionPhase.connecting => text.activityConnecting,
      CompanionPhase.synchronizing => text.activitySynchronizing,
      CompanionPhase.unavailable => text.activityUnavailable,
      CompanionPhase.starting => text.activityStarting,
      CompanionPhase.closing => text.activityClosing,
      CompanionPhase.stopped => text.activityStopped,
      CompanionPhase.failed => text.activityFailed,
      CompanionPhase.ready => text.activityReady,
      CompanionPhase.receiving => text.activityReceiving,
      CompanionPhase.processing => text.activityProcessing,
      CompanionPhase.thinking => text.activityThinking,
      CompanionPhase.acting => actionLabel(experience.callPath, text),
    };

/// One namespace classification supports live verbs and historical action names.
enum _ActionKind { phone, computer, notebook, browser, message, other }

// Message and browser paths are nested under device namespaces and must be selected first.
_ActionKind _actionKind(String? path) => switch (path) {
  'me.phone.chat.send' => _ActionKind.message,
  final String value when value.contains('.browser.') => _ActionKind.browser,
  final String value when value.startsWith('me.phone.') => _ActionKind.phone,
  final String value when value.startsWith('me.computer.') =>
    _ActionKind.computer,
  final String value when value.startsWith('me.notebook.') =>
    _ActionKind.notebook,
  _ => _ActionKind.other,
};

/// Live action labels describe only a currently running owner.
String actionLabel(String? path, PhoneL10n text) => switch (_actionKind(path)) {
  _ActionKind.message => text.actionMessage,
  _ActionKind.browser => text.actionBrowser,
  _ActionKind.phone => text.actionPhone,
  _ActionKind.computer => text.actionComputer,
  _ActionKind.notebook => text.actionNotebook,
  _ActionKind.other => text.activityActing,
};

/// Recorded receipts use nouns so a finished call never sounds as if it is still executing.
String actionName(String? path, PhoneL10n text) => switch (_actionKind(path)) {
  _ActionKind.message => text.actionNameMessage,
  _ActionKind.browser => text.actionNameBrowser,
  _ActionKind.phone => text.actionNamePhone,
  _ActionKind.computer => text.actionNameComputer,
  _ActionKind.notebook => text.actionNameNotebook,
  _ActionKind.other => text.actionNameOther,
};

/// A receipt describes the execution boundary, never the business outcome of a target app.
String receiptLabel(String? state, PhoneL10n text) => switch (state) {
  'confirmed' => text.receiptConfirmed,
  'failed' => text.receiptFailed,
  'started' => text.receiptStarted,
  _ => text.receiptUnknown,
};

/// Expanded details describe the actual boundary, rather than suggesting a reply or successful effect.
String activityDetail(CompanionPhase phase, PhoneL10n text) => switch (phase) {
  CompanionPhase.offline => text.detailOffline,
  CompanionPhase.connecting => text.detailConnecting,
  CompanionPhase.synchronizing => text.detailSynchronizing,
  CompanionPhase.unavailable => text.detailUnavailable,
  CompanionPhase.starting => text.detailStarting,
  CompanionPhase.closing => text.detailClosing,
  CompanionPhase.stopped => text.detailStopped,
  CompanionPhase.failed => text.detailFailed,
  CompanionPhase.ready => text.detailReady,
  CompanionPhase.receiving => text.detailReceiving,
  CompanionPhase.processing => text.detailProcessing,
  CompanionPhase.thinking => text.detailThinking,
  CompanionPhase.acting => text.detailActing,
};

/// This label stays attached to its message and follows causal facts, even when other work is active.
String messageLabel(MessagePhase phase, PhoneL10n text) => switch (phase) {
  MessagePhase.saved => text.pending,
  MessagePhase.delivered => text.engineAccepted,
  MessagePhase.waiting => text.messageWaiting,
  MessagePhase.claimed => text.messageClaimed,
  MessagePhase.thinking => text.messageThinking,
  MessagePhase.acting => text.messageActing,
  MessagePhase.finished => text.messageFinished,
  MessagePhase.recorded => text.messageRecorded,
  MessagePhase.failed => text.messageFailed,
  MessagePhase.stale => text.messageStale,
  MessagePhase.unavailable => text.messageProgressUnavailable,
};

/// A single expressive body anchors either an empty conversation or the live conversation header.
class CompanionPresence extends StatelessWidget {
  const CompanionPresence({
    super.key,
    required this.experience,
    this.hero = false,
  });
  final SubjectExperience experience;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final text = PhoneL10n.of(context);
    final colors = PhoneColors.of(context);
    final statusColor = switch (experience.phase) {
      CompanionPhase.failed => colors.failed,
      CompanionPhase.receiving => colors.waiting,
      CompanionPhase.ready => colors.ink,
      CompanionPhase.processing ||
      CompanionPhase.thinking ||
      CompanionPhase.acting => colors.active,
      _ => colors.muted,
    };
    final expandedCopy =
        hero ||
        MediaQuery.textScalerOf(context).scale(MobileTokens.bodySize) <=
            MobileTokens.bodySize * 1.4;
    final words = Column(
      crossAxisAlignment: hero
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            activityLabel(experience, text),
            textAlign: hero ? TextAlign.center : TextAlign.start,
            style:
                (hero
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
          ),
        ),
        if (expandedCopy) ...[
          const SizedBox(height: Cel.space / 2),
          Text(
            activityDetail(experience.phase, text),
            textAlign: hero ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: colors.muted,
              fontSize: MobileTokens.labelSize,
              height: MobileTokens.lineHeight,
            ),
          ),
        ],
      ],
    );
    return Material(
      color: hero ? colors.hero : colors.surface,
      borderRadius: BorderRadius.circular(MobileTokens.panelRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
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
                      text.activityDetails,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: Cel.space),
                    Text(activityDetail(experience.phase, text)),
                    const SizedBox(height: Cel.space),
                    Text(text.statusNotReply),
                    if (experience.callPath != null) ...[
                      const SizedBox(height: Cel.space),
                      SelectableText(
                        experience.callPath!,
                        style: TextStyle(color: colors.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Cel.space),
          child: hero
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CompanionMascot(phase: experience.phase, hero: true),
                    const SizedBox(height: Cel.space),
                    words,
                  ],
                )
              : Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.hero,
                        borderRadius: BorderRadius.circular(
                          MobileTokens.bubbleRadius,
                        ),
                      ),
                      child: CompanionMascot(phase: experience.phase),
                    ),
                    const SizedBox(width: Cel.space),
                    Expanded(child: words),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Entry motion is interruptible and physical. History rows do not all animate on every refresh.
class MessageArrival extends StatefulWidget {
  const MessageArrival({super.key, required this.child, required this.animate});
  final Widget child;
  final bool animate;
  @override
  State<MessageArrival> createState() => _MessageArrivalState();
}

class _MessageArrivalState extends State<MessageArrival>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController.unbounded(
    vsync: this,
    value: widget.animate ? 0 : 1,
  );
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
      controller.value = 1;
      started = true;
      return;
    }
    if (started) return;
    started = true;
    if (!widget.animate) {
      controller.value = 1;
      return;
    }
    controller.animateWith(
      SpringSimulation(
        SpringDescription(
          mass: MobileTokens.springMass,
          stiffness: MobileTokens.springStiffness,
          damping: MobileTokens.springDamping,
        ),
        0,
        1,
        0,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: controller.value.clamp(0, 1),
      child: Transform.translate(
        offset: Offset(0, Cel.space * (1 - controller.value)),
        child: child,
      ),
    ),
  );
}
