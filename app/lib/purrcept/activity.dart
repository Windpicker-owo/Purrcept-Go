/// One live status surface joins a subject's public identity, explicit stage and peeking mascot banner.
library;

import 'dart:math' as math;

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

/// A single expressive body anchors either an empty conversation or the peeking stage banner above composer.
/// Static when idle/ready or under reduced motion; state-reactive cel color drift when actively working.
class CompanionPresence extends StatefulWidget {
  const CompanionPresence({
    super.key,
    required this.experience,
    this.hero = false,
    this.footer,
  });
  final SubjectExperience experience;
  final bool hero;
  final Widget? footer;

  @override
  State<CompanionPresence> createState() => _CompanionPresenceState();
}

class _CompanionPresenceState extends State<CompanionPresence>
    with SingleTickerProviderStateMixin {
  late final wave = AnimationController(
    vsync: this,
    duration: MobileTokens.workingPulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWave();
  }

  @override
  void didUpdateWidget(CompanionPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.experience.phase != widget.experience.phase) _syncWave();
  }

  void _syncWave() {
    wave.stop();
    wave.value = 0;
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    if (widget.experience.working) {
      wave.repeat();
    }
  }

  @override
  void dispose() {
    wave.dispose();
    super.dispose();
  }

  Future<void> _openDetails(BuildContext context) {
    final text = PhoneL10n.of(context);
    final colors = PhoneColors.of(context);
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
                  text.activityDetails,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: Cel.space),
                Text(activityDetail(widget.experience.phase, text)),
                const SizedBox(height: Cel.space),
                Text(text.statusNotReply),
                if (widget.experience.callPath != null) ...[
                  const SizedBox(height: Cel.space),
                  SelectableText(
                    widget.experience.callPath!,
                    style: TextStyle(color: colors.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = PhoneL10n.of(context);
    final colors = PhoneColors.of(context);
    final phase = widget.experience.phase;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final statusColor = switch (phase) {
      CompanionPhase.failed => colors.failed,
      CompanionPhase.receiving => colors.waiting,
      CompanionPhase.ready => colors.ink,
      CompanionPhase.processing ||
      CompanionPhase.thinking ||
      CompanionPhase.acting => colors.active,
      _ => colors.muted,
    };
    final expandedCopy =
        widget.hero ||
        MediaQuery.textScalerOf(context).scale(MobileTokens.bodySize) <=
            MobileTokens.bodySize * 1.35;

    final words = Column(
      crossAxisAlignment: widget.hero
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            activityLabel(widget.experience, text),
            textAlign: widget.hero ? TextAlign.center : TextAlign.start,
            style:
                (widget.hero
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
          ),
        ),
        if (expandedCopy) ...[
          const SizedBox(height: 3),
          Text(
            activityDetail(phase, text),
            textAlign: widget.hero ? TextAlign.center : TextAlign.start,
            maxLines: widget.hero ? 4 : 2,
            overflow: widget.hero ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.muted,
              fontSize: MobileTokens.labelSize,
              height: 1.38,
            ),
          ),
        ],
      ],
    );

    if (widget.hero) {
      return Container(
        decoration: colors.celCard(
          radius: MobileTokens.heroRadius,
          border: colors.ink,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: wave,
                  builder: (context, _) => CustomPaint(
                    painter: _BannerBackdropPainter(
                      phase: phase,
                      progress: reduced ? 0 : wave.value,
                      dark: colors.dark,
                    ),
                  ),
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _openDetails(context),
                child: Padding(
                  padding: const EdgeInsets.all(Cel.space * 1.25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CompanionMascot(phase: phase, hero: true),
                      const SizedBox(height: Cel.spaceSm),
                      words,
                      if (widget.footer != null) ...[
                        const SizedBox(height: Cel.space),
                        widget.footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Compact peeking mascot stage banner: lower chin tucked behind opaque foreground banner ledge!
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        // Peeking mascot behind banner's top right edge (cheek-level horizon)
        Positioned(
          right: 16,
          top: 0,
          child: IgnorePointer(
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 0.76,
                child: CompanionMascot(phase: phase),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.ink, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: phase == CompanionPhase.thinking
                      ? colors.celShadowPaper
                      : colors.celShadow,
                  offset: const Offset(2, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: wave,
                      builder: (context, _) => CustomPaint(
                        painter: _BannerBackdropPainter(
                          phase: phase,
                          progress: reduced ? 0 : wave.value,
                          dark: colors.dark,
                        ),
                      ),
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => _openDetails(context),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 9, 78, 9),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: words),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerBackdropPainter extends CustomPainter {
  const _BannerBackdropPainter({
    required this.phase,
    required this.progress,
    required this.dark,
  });

  final CompanionPhase phase;
  final double progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (phase == CompanionPhase.thinking) {
      // Sky × Warm Sakura-Peach dual-tone breathing tide
      final shift = math.sin(progress * math.pi * 2) * size.width * 0.14;
      final skyPaint = Paint()
        ..color = (dark ? MobileTokens.darkHero : Cel.brandContainer)
            .withValues(alpha: dark ? 0.55 : 0.72);
      final peachPaint = Paint()
        ..color = (dark ? MobileTokens.darkBlushContainer : Cel.blushContainer)
            .withValues(alpha: dark ? 0.55 : 0.78);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.28 + shift, size.height * 0.5),
          width: size.width * 0.72,
          height: size.height * 2.2,
        ),
        skyPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.76 - shift, size.height * 0.5),
          width: size.width * 0.68,
          height: size.height * 2.2,
        ),
        peachPaint,
      );
      return;
    }

    if (phase == CompanionPhase.acting || phase == CompanionPhase.processing) {
      // Crisp cyan cel stream sweep
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = (dark ? MobileTokens.darkActiveContainer : Cel.activeContainer)
              .withValues(alpha: dark ? 0.48 : 0.68),
      );
      final sweepX = -size.width * 0.4 + (size.width * 1.65) * progress;
      final ribbon = Path()
        ..moveTo(sweepX, 0)
        ..lineTo(sweepX + size.width * 0.34, 0)
        ..lineTo(sweepX + size.width * 0.24, size.height)
        ..lineTo(sweepX - size.width * 0.1, size.height)
        ..close();
      canvas.drawPath(
        ribbon,
        Paint()
          ..color = (dark ? MobileTokens.darkHero : Cel.brandContainer)
              .withValues(alpha: dark ? 0.6 : 0.85),
      );
      return;
    }

    if (phase == CompanionPhase.receiving) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = (dark ? MobileTokens.darkTapeContainer : Cel.waitingContainer)
              .withValues(alpha: 0.65),
      );
      return;
    }

    if (phase == CompanionPhase.failed) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = (dark ? MobileTokens.darkBlushContainer : Cel.failedContainer)
              .withValues(alpha: 0.72),
      );
      return;
    }

    // Quiet/Static ready & offline sash: zero animation
    final sash = Path()
      ..moveTo(size.width * 0.64, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.52, size.height)
      ..close();
    canvas.drawPath(
      sash,
      Paint()
        ..color = (dark ? MobileTokens.darkHero : Cel.atmosphereSky)
            .withValues(alpha: dark ? 0.42 : 0.72),
    );
  }

  @override
  bool shouldRepaint(_BannerBackdropPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.progress != progress ||
      oldDelegate.dark != dark;
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
