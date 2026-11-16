/// Voice message waveform playback bubbles and hold-to-talk / tap-to-record Cel composer controls.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device.dart';
import 'l10n/app_localizations.dart';
import 'mobile_theme.dart';
import 'tokens.dart';

String formatDurationMs(int ms) {
  final totalSeconds = math.max(1, (ms / 1000).round());
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes > 0) {
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  return '0:${seconds.toString().padLeft(2, '0')}';
}

List<int> parseWaveform(Object? raw) {
  if (raw is List && raw.isNotEmpty) {
    return raw
        .map((item) => (item is num ? item.toInt() : 28).clamp(12, 98))
        .take(28)
        .toList();
  }
  return const [
    22, 38, 62, 48, 76, 84, 54, 36, 68, 90, 64, 42,
    58, 82, 46, 32, 66, 74, 52, 38, 44, 28,
  ];
}

/// Interactive voice bubble content with play/stop control, 22-bar waveform and duration badge.
class VoiceMessageBubble extends StatelessWidget {
  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.fromUser,
    required this.device,
  });

  final Map<String, dynamic> message;
  final bool fromUser;
  final DeviceController device;

  @override
  Widget build(BuildContext context) {
    final text = PhoneL10n.of(context);
    final colors = PhoneColors.of(context);
    final messageId = message['message_id'] as String? ?? '';
    final localPath = message['local_path'] as String?;
    final durationMs = (message['duration_ms'] as num?)?.toInt() ?? 3000;
    final bars = parseWaveform(message['waveform']);
    final isPlaying =
        messageId.isNotEmpty && device.playingMessageId == messageId;
    final total = isPlaying && device.playingDurationMs > 0
        ? device.playingDurationMs
        : math.max(durationMs, 1);
    final progress = isPlaying
        ? (device.playingPositionMs / total).clamp(0.0, 1.0)
        : 0.0;
    final canPlay = localPath != null && localPath.isNotEmpty;

    final rawCaption = (message['text'] as String? ?? '').trim();
    final isSyntheticCaption =
        rawCaption.startsWith('[语音') || rawCaption.startsWith('[Voice');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: isPlaying ? text.stopVoice : text.playVoice,
              child: InkWell(
                onTap: !canPlay
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        device.invokeMedia('voice_toggle_play', {
                          'message_id': messageId,
                          'local_path': localPath,
                        });
                      },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: fromUser ? colors.brandFill : colors.activeContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.ink, width: 1.4),
                  ),
                  child: Icon(
                    isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 22,
                    color: fromUser ? colors.onBrand : colors.active,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 96, maxWidth: 168),
                child: SizedBox(
                  height: 30,
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      bars: bars,
                      progress: progress,
                      activeColor: fromUser ? colors.brand : colors.activeSignal,
                      idleColor: colors.muted.withValues(alpha: 0.42),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatDurationMs(
                isPlaying && device.playingPositionMs > 0
                    ? device.playingPositionMs
                    : durationMs,
              ),
              style: TextStyle(
                fontSize: MobileTokens.labelSize,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: colors.inkSecondary,
              ),
            ),
          ],
        ),
        if (rawCaption.isNotEmpty && !isSyntheticCaption) ...[
          const SizedBox(height: 6),
          SelectableText(
            rawCaption,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.idleColor,
  });

  final List<int> bars;
  final double progress;
  final Color activeColor;
  final Color idleColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final count = bars.length;
    final gap = 3.0;
    final barWidth = math.max(
      2.5,
      (size.width - gap * (count - 1)) / count,
    );
    final activePaint = Paint()..color = activeColor;
    final idlePaint = Paint()..color = idleColor;

    for (var i = 0; i < count; i++) {
      final ratio = (i + 0.5) / count;
      final h = (bars[i] / 100.0 * size.height).clamp(4.0, size.height);
      final left = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(left + barWidth / 2, size.height / 2),
          width: barWidth,
          height: h,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        progress > 0 && ratio <= progress ? activePaint : idlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.bars != bars;
}

/// Floating HUD shown above the composer while recording a voice message.
class VoiceRecordingHud extends StatefulWidget {
  const VoiceRecordingHud({
    super.key,
    required this.startedAtMs,
    required this.level,
    required this.cancelling,
  });

  final int startedAtMs;
  final int level;
  final bool cancelling;

  @override
  State<VoiceRecordingHud> createState() => _VoiceRecordingHudState();
}

class _VoiceRecordingHudState extends State<VoiceRecordingHud> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = PhoneL10n.of(context);
    final colors = PhoneColors.of(context);
    final elapsed = widget.startedAtMs > 0
        ? DateTime.now().millisecondsSinceEpoch - widget.startedAtMs
        : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(Cel.space, 0, Cel.space, Cel.spaceXs),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: colors.celCard(
        fill: widget.cancelling ? colors.failedContainer : colors.activeContainer,
        border: widget.cancelling ? colors.failed : colors.activeSignal,
        radius: 20,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.cancelling ? colors.failed : colors.blushSignal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDurationMs(math.max(1000, elapsed)),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: colors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.cancelling ? text.releaseToCancel : text.slideUpToCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: MobileTokens.labelSize,
                fontWeight: FontWeight.w600,
                color: widget.cancelling ? colors.failed : colors.inkSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 54,
            height: 20,
            child: CustomPaint(
              painter: _LiveMicBarsPainter(
                level: widget.level,
                color: widget.cancelling ? colors.failed : colors.active,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMicBarsPainter extends CustomPainter {
  const _LiveMicBarsPainter({required this.level, required this.color});
  final int level;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const weights = [0.45, 0.75, 1.0, 0.85, 0.55, 0.9, 0.6];
    final w = 4.0;
    final gap = (size.width - weights.length * w) / (weights.length - 1);
    for (var i = 0; i < weights.length; i++) {
      final h = ((level / 100.0) * weights[i] * size.height).clamp(4.0, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(i * (w + gap) + w / 2, size.height / 2),
            width: w,
            height: h,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LiveMicBarsPainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.color != color;
}

/// Tactile Hold-to-Talk bar (also supports tap-to-start / tap-to-send for accessibility).
class VoiceHoldToTalkBar extends StatefulWidget {
  const VoiceHoldToTalkBar({
    super.key,
    required this.device,
    required this.onCancelChanged,
    required this.onVoiceRecorded,
  });

  final DeviceController device;
  final ValueChanged<bool> onCancelChanged;
  final ValueChanged<Map<String, dynamic>> onVoiceRecorded;

  @override
  State<VoiceHoldToTalkBar> createState() => _VoiceHoldToTalkBarState();
}

class _VoiceHoldToTalkBarState extends State<VoiceHoldToTalkBar> {
  bool _cancelling = false;
  bool _holding = false;

  Future<void> _begin() async {
    if (widget.device.isRecordingVoice) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _holding = true;
      _cancelling = false;
    });
    widget.onCancelChanged(false);
    final started = await widget.device.invokeMedia('voice_start');
    if (started == null && mounted) {
      setState(() => _holding = false);
    }
  }

  Future<void> _finish({required bool cancel}) async {
    final shouldCancel = cancel || _cancelling;
    setState(() {
      _holding = false;
      _cancelling = false;
    });
    widget.onCancelChanged(false);
    if (!widget.device.isRecordingVoice) return;
    if (shouldCancel) {
      HapticFeedback.lightImpact();
      await widget.device.invokeMedia('voice_cancel');
      return;
    }
    final recorded = await widget.device.invokeMedia('voice_stop');
    if (recorded != null && recorded['local_path'] is String) {
      HapticFeedback.mediumImpact();
      widget.onVoiceRecorded(recorded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = PhoneL10n.of(context);
    final colors = PhoneColors.of(context);
    final active = _holding || widget.device.isRecordingVoice;

    return GestureDetector(
      onTap: () {
        if (widget.device.isRecordingVoice) {
          _finish(cancel: false);
        } else {
          _begin();
        }
      },
      onLongPressStart: (_) => _begin(),
      onLongPressMoveUpdate: (details) {
        final nextCancel = details.localOffsetFromOrigin.dy < -48;
        if (nextCancel != _cancelling) {
          HapticFeedback.selectionClick();
          setState(() => _cancelling = nextCancel);
          widget.onCancelChanged(nextCancel);
        }
      },
      onLongPressEnd: (_) => _finish(cancel: _cancelling),
      onLongPressCancel: () => _finish(cancel: true),
      child: Semantics(
        button: true,
        label: active ? text.releaseToSend : text.holdToTalk,
        hint: text.tapToRecordHint,
        child: AnimatedContainer(
          duration: MobileTokens.effects,
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _cancelling
                ? colors.failedContainer
                : active
                ? colors.brandContainer
                : colors.surface,
            borderRadius: BorderRadius.circular(MobileTokens.bubbleRadius),
            border: Border.all(
              color: _cancelling
                  ? colors.failed
                  : active
                  ? colors.brand
                  : colors.outline,
              width: active ? 2 : 1.5,
            ),
            boxShadow: active
                ? const []
                : [
                    BoxShadow(
                      color: colors.celShadow,
                      offset: const Offset(0, 2.5),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _cancelling
                    ? Icons.close_rounded
                    : active
                    ? Icons.graphic_eq_rounded
                    : Icons.mic_none_rounded,
                size: 20,
                color: _cancelling
                    ? colors.failed
                    : active
                    ? colors.brand
                    : colors.ink,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _cancelling
                      ? text.releaseToCancel
                      : active
                      ? text.releaseToSend
                      : text.holdToTalk,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _cancelling
                        ? colors.failed
                        : active
                        ? colors.brand
                        : colors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
