/// Purrcept's own white cat is a compact state instrument, drawn locally with no proprietary DSH art.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'experience.dart';
import 'tokens.dart';

/// One body in the current scene. Offline eyes rest; thought looks up; action looks toward its path.
/// Reduced motion and inactive routes cancel timers and tickers, leaving the same readable pose.
class CompanionMascot extends StatefulWidget {
  const CompanionMascot({super.key, required this.phase, this.hero = false});
  final CompanionPhase phase;
  final bool hero;
  @override
  State<CompanionMascot> createState() => _CompanionMascotState();
}

class _CompanionMascotState extends State<CompanionMascot>
    with TickerProviderStateMixin {
  late final pulse = AnimationController(
    vsync: this,
    duration: MobileTokens.workingPulse,
  );
  late final blink = AnimationController(
    vsync: this,
    duration: MobileTokens.blink,
  );
  Timer? blinkTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    configure();
  }

  @override
  void didUpdateWidget(CompanionMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) configure();
  }

  /// Timers only schedule an idle blink; they never advance or invent an Engine work phase.
  void configure() {
    blinkTimer?.cancel();
    pulse.stop();
    blink.stop();
    blink.value = 0;
    pulse.value = 0;
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    if ({
      CompanionPhase.thinking,
      CompanionPhase.acting,
      CompanionPhase.processing,
    }.contains(widget.phase)) {
      pulse.repeat();
    } else if (widget.phase == CompanionPhase.ready) {
      blinkTimer = Timer.periodic(
        MobileTokens.blinkInterval,
        (_) => blink.forward(from: 0),
      );
    }
  }

  @override
  void dispose() {
    blinkTimer?.cancel();
    pulse.dispose();
    blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final size = widget.hero
        ? MobileTokens.avatarSize * 3.6
        : MobileTokens.avatarSize;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size * .82,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: Listenable.merge([pulse, blink]),
              builder: (context, _) => CustomPaint(
                painter: _CatPainter(
                  phase: widget.phase,
                  // Fur stays white in both themes, so eyes use contrast against fur rather than page ink.
                  eye: switch (widget.phase) {
                    CompanionPhase.thinking ||
                    CompanionPhase.acting ||
                    CompanionPhase.processing => Cel.active,
                    CompanionPhase.ready => Cel.ink,
                    CompanionPhase.receiving => Cel.waiting,
                    CompanionPhase.failed => Cel.failed,
                    _ => Cel.muted,
                  },
                  pulse: reduced ? 0 : pulse.value,
                  blink: reduced ? 0 : math.sin(blink.value * math.pi),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Geometry is normalized to 134 × 110; only the eyes carry a state color.
class _CatPainter extends CustomPainter {
  _CatPainter({
    required this.phase,
    required this.eye,
    required this.pulse,
    required this.blink,
  });
  final CompanionPhase phase;
  final Color eye;
  final double pulse;
  final double blink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 134, size.height / 110);
    final working =
        phase == CompanionPhase.thinking ||
        phase == CompanionPhase.acting ||
        phase == CompanionPhase.processing;
    final breath = working ? math.sin(pulse * math.pi * 2) * 1.2 : 0.0;
    canvas.translate(0, breath);
    final paint = Paint()..color = MobileTokens.fur;
    final ear = Path()
      ..moveTo(24, 47)
      ..quadraticBezierTo(13, 1, 24, 5)
      ..quadraticBezierTo(37, 7, 49, 28)
      ..close();
    canvas.save();
    canvas.translate(32, 31);
    if (phase == CompanionPhase.thinking) {
      canvas.rotate(math.sin(pulse * math.pi * 2) * .07);
    }
    canvas.translate(-32, -31);
    canvas.drawPath(ear, paint);
    canvas.restore();
    final right = Path()
      ..moveTo(87, 29)
      ..quadraticBezierTo(105, 1, 116, 6)
      ..quadraticBezierTo(124, 10, 112, 48)
      ..close();
    canvas.drawPath(right, paint);
    paint.color = MobileTokens.furShade;
    canvas.drawPath(
      Path()
        ..moveTo(24, 13)
        ..lineTo(37, 32)
        ..lineTo(25, 36)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(111, 14)
        ..lineTo(98, 33)
        ..lineTo(111, 36)
        ..close(),
      paint,
    );
    final head = Path()
      ..moveTo(34, 29)
      ..cubicTo(13, 36, 6, 58, 10, 82)
      ..cubicTo(13, 108, 36, 119, 69, 119)
      ..cubicTo(105, 119, 131, 104, 128, 76)
      ..cubicTo(128, 46, 108, 28, 83, 25)
      ..lineTo(72, 13)
      ..lineTo(69, 24)
      ..lineTo(59, 17)
      ..lineTo(60, 27)
      ..cubicTo(51, 25, 43, 26, 34, 29)
      ..close();
    paint.color = MobileTokens.fur;
    canvas.drawPath(head, paint);
    canvas.save();
    canvas.clipPath(head);
    paint.color = MobileTokens.furShade;
    canvas.drawPath(
      Path()
        ..moveTo(124, 49)
        ..cubicTo(128, 92, 95, 107, 54, 115)
        ..lineTo(130, 127)
        ..lineTo(144, 70)
        ..close(),
      paint,
    );
    canvas.restore();
    paint.color = MobileTokens.blush;
    canvas.drawOval(const Rect.fromLTWH(23, 78, 17, 6), paint);
    canvas.drawOval(const Rect.fromLTWH(96, 78, 17, 6), paint);
    final resting = phase == CompanionPhase.offline;
    final x = phase == CompanionPhase.acting
        ? 3.0
        : phase == CompanionPhase.processing
        ? -2.0
        : 0.0;
    final y = phase == CompanionPhase.thinking
        ? -4.0
        : phase == CompanionPhase.acting
        ? 2.0
        : 0.0;
    final height = resting ? 3.0 : 18 * (1 - blink) + 2;
    paint.color = eye;
    for (final left in [45.0, 80.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(left + x, 66 + y),
            width: 8,
            height: height,
          ),
          const Radius.circular(5),
        ),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CatPainter old) =>
      old.phase != phase ||
      old.eye != eye ||
      old.pulse != pulse ||
      old.blink != blink;
}
