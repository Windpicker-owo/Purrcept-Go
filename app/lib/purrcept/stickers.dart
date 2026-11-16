/// Built-in companion artwork and the cached Engine library shared by QQ and phone chat.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device.dart';
import 'l10n/app_localizations.dart';
import 'mobile_theme.dart';
import 'press_feedback.dart';
import 'tokens.dart';

class BuiltInSticker {
  const BuiltInSticker({
    required this.id,
    required this.zhLabel,
    required this.enLabel,
    required this.accent,
    required this.bg,
  });
  final String id;
  final String zhLabel;
  final String enLabel;
  final Color accent;
  final Color bg;

  String label(bool isZh) => isZh ? zhLabel : enLabel;
  String wireText(bool isZh) => isZh ? '[贴纸：$zhLabel]' : '[Sticker: $enLabel]';
}

const kBuiltInStickers = <BuiltInSticker>[
  BuiltInSticker(
    id: 'peek_curious',
    zhLabel: '探头偷看',
    enLabel: 'Peek!',
    accent: Cel.brandFill,
    bg: Cel.brandContainer,
  ),
  BuiltInSticker(
    id: 'pat_head',
    zhLabel: '摸摸头',
    enLabel: 'Pat pat',
    accent: Cel.blushSignal,
    bg: Cel.blushContainer,
  ),
  BuiltInSticker(
    id: 'sparkle_eyes',
    zhLabel: '星星眼',
    enLabel: 'Sparkle!',
    accent: Cel.tapeSignal,
    bg: Cel.tapeContainer,
  ),
  BuiltInSticker(
    id: 'hug_warm',
    zhLabel: '贴贴充电',
    enLabel: 'Warm hug',
    accent: Cel.blushSignal,
    bg: Cel.paperBlush,
  ),
  BuiltInSticker(
    id: 'cheer_flag',
    zhLabel: '摇旗加油',
    enLabel: 'Cheer up!',
    accent: Cel.activeSignal,
    bg: Cel.activeContainer,
  ),
  BuiltInSticker(
    id: 'thinking_hmm',
    zhLabel: '托腮思考',
    enLabel: 'Hmm...',
    accent: Cel.brand,
    bg: Cel.atmosphereSky,
  ),
  BuiltInSticker(
    id: 'sleepy_curl',
    zhLabel: '困困小憩',
    enLabel: 'Sleepy...',
    accent: Cel.pausedSignal,
    bg: Cel.pausedContainer,
  ),
  BuiltInSticker(
    id: 'pout_hmph',
    zhLabel: '鼓脸哼哼',
    enLabel: 'Hmph!',
    accent: Cel.failedSignal,
    bg: Cel.failedContainer,
  ),
  BuiltInSticker(
    id: 'ok_salute',
    zhLabel: '收到包办',
    enLabel: 'Got it!',
    accent: Cel.successSignal,
    bg: Cel.successContainer,
  ),
  BuiltInSticker(
    id: 'tea_break',
    zhLabel: '喝口暖茶',
    enLabel: 'Tea break',
    accent: Cel.tapeSignal,
    bg: Cel.paperSunken,
  ),
  BuiltInSticker(
    id: 'heart_tail',
    zhLabel: '比心喜欢',
    enLabel: 'Love ya',
    accent: Cel.blushSignal,
    bg: Cel.blushContainer,
  ),
  BuiltInSticker(
    id: 'shock_ahoge',
    zhLabel: '呆毛震惊',
    enLabel: 'Whoa?!',
    accent: Cel.waitingSignal,
    bg: Cel.waitingContainer,
  ),
];

BuiltInSticker? findBuiltInSticker(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final item in kBuiltInStickers) {
    if (item.id == id) return item;
  }
  return null;
}

/// Detect legacy or plain-text sticker marker like `[贴纸：摸摸头]` when sticker_id is absent.
BuiltInSticker? matchStickerFromText(String text) {
  final trimmed = text.trim();
  for (final item in kBuiltInStickers) {
    if (trimmed == '[贴纸：${item.zhLabel}]' ||
        trimmed == '[Sticker: ${item.enLabel}]') {
      return item;
    }
  }
  return null;
}

/// Die-cut anime cel sticker rendered in chat or inside the sticker drawer.
class CelStickerView extends StatelessWidget {
  const CelStickerView({
    super.key,
    this.stickerId,
    this.localPath,
    this.caption,
    this.size = MobileTokens.stickerSize,
  });

  final String? stickerId;
  final String? localPath;
  final String? caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = PhoneColors.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final builtIn = findBuiltInSticker(stickerId);

    if (builtIn != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size - 6,
              height: size - 6,
              decoration: BoxDecoration(
                color: builtIn.bg,
                borderRadius: BorderRadius.circular(size * 0.28),
                border: Border.all(color: Cel.ink, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Cel.ink,
                    offset: Offset(2.5, 2.5),
                    blurRadius: 0,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(painter: _StickerArtPainter(sticker: builtIn)),
            ),
            Positioned(
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Cel.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Cel.ink, width: 1.5),
                ),
                child: Text(
                  caption ?? builtIn.label(isZh),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Cel.ink,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (localPath != null && localPath!.isNotEmpty) {
      final file = File(localPath!);
      if (file.existsSync()) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outline, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: colors.celShadow,
                offset: const Offset(2, 3),
                blurRadius: 0,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(file, fit: BoxFit.contain),
        );
      }
    }

    return Container(
      width: size * 0.85,
      height: size * 0.85,
      decoration: colors.celCard(radius: 20),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        caption ?? '✦',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colors.ink,
        ),
      ),
    );
  }
}

class _StickerArtPainter extends CustomPainter {
  const _StickerArtPainter({required this.sticker});
  final BuiltInSticker sticker;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 120);

    final fur = Paint()..color = MobileTokens.fur;
    final shade = Paint()..color = MobileTokens.furShade;
    final blush = Paint()..color = MobileTokens.blush;
    final ink = Paint()..color = Cel.ink;
    final stroke = Paint()
      ..color = Cel.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accent = Paint()..color = sticker.accent;

    // Halftone sparkle backdrop dots
    final dot = Paint()..color = sticker.accent.withValues(alpha: 0.18);
    for (final pt in const [
      Offset(18, 22),
      Offset(102, 20),
      Offset(16, 86),
      Offset(104, 82),
    ]) {
      canvas.drawCircle(pt, 4, dot);
    }

    // Cat ears + round dumpling head
    final headY = sticker.id == 'peek_curious' ? 16.0 : 4.0;
    canvas.save();
    canvas.translate(0, headY);

    final leftEar = Path()
      ..moveTo(26, 56)
      ..quadraticBezierTo(18, 18, 30, 22)
      ..quadraticBezierTo(42, 26, 48, 42)
      ..close();
    final rightEar = Path()
      ..moveTo(94, 56)
      ..quadraticBezierTo(102, 18, 90, 22)
      ..quadraticBezierTo(78, 26, 72, 42)
      ..close();
    canvas.drawPath(leftEar, fur);
    canvas.drawPath(leftEar, stroke);
    canvas.drawPath(rightEar, fur);
    canvas.drawPath(rightEar, stroke);
    canvas.drawOval(const Rect.fromLTWH(20, 36, 80, 66), fur);
    canvas.drawArc(
      const Rect.fromLTWH(20, 36, 80, 66),
      -0.3,
      2.1,
      false,
      Paint()
        ..color = shade.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawOval(const Rect.fromLTWH(20, 36, 80, 66), stroke);

    // Lightning ahoge tuft
    final ahoge = Path()
      ..moveTo(60, 36)
      ..lineTo(65, 22)
      ..lineTo(57, 22)
      ..lineTo(63, 10);
    canvas.drawPath(
      ahoge,
      Paint()
        ..color = sticker.id == 'shock_ahoge' ? sticker.accent : Cel.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Cheeks
    final cheekRadius = sticker.id == 'pout_hmph' ? 10.0 : 7.5;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(35, 75),
        width: cheekRadius * 2,
        height: 9,
      ),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(85, 75),
        width: cheekRadius * 2,
        height: 9,
      ),
      blush,
    );

    // Expressive eyes & props per sticker ID
    switch (sticker.id) {
      case 'sparkle_eyes':
        for (final cx in const [45.0, 75.0]) {
          final star = Path()
            ..moveTo(cx, 52)
            ..quadraticBezierTo(cx + 2, 62, cx + 10, 64)
            ..quadraticBezierTo(cx + 2, 66, cx, 76)
            ..quadraticBezierTo(cx - 2, 66, cx - 10, 64)
            ..quadraticBezierTo(cx - 2, 62, cx, 52)
            ..close();
          canvas.drawPath(star, accent);
          canvas.drawPath(star, stroke..strokeWidth = 1.8);
        }
      case 'pat_head':
      case 'hug_warm':
      case 'heart_tail':
        // Happy curved ^ ^ eyes
        for (final cx in const [45.0, 75.0]) {
          canvas.drawArc(
            Rect.fromCenter(center: Offset(cx, 66), width: 14, height: 12),
            math.pi * 1.1,
            math.pi * 0.8,
            false,
            stroke,
          );
        }
        if (sticker.id == 'pat_head') {
          // Gentle patting hand cloud on top
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(38, 12, 44, 16),
              const Radius.circular(10),
            ),
            accent,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(38, 12, 44, 16),
              const Radius.circular(10),
            ),
            stroke,
          );
        } else {
          // Floating heart emblem
          _drawHeart(canvas, const Offset(94, 30), 11, accent, stroke);
        }
      case 'sleepy_curl':
        for (final cx in const [45.0, 75.0]) {
          canvas.drawArc(
            Rect.fromCenter(center: Offset(cx, 66), width: 13, height: 8),
            0.15,
            math.pi * 0.7,
            false,
            stroke,
          );
        }
        // Zzz bubble
        final tp = TextPainter(
          text: TextSpan(
            text: 'Zzz',
            style: TextStyle(
              color: sticker.accent,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, const Offset(82, 12));
      case 'pout_hmph':
        // Angled > < brows + puffed mouth
        canvas.drawLine(const Offset(38, 56), const Offset(50, 61), stroke);
        canvas.drawLine(const Offset(82, 56), const Offset(70, 61), stroke);
        canvas.drawCircle(const Offset(45, 65), 4.2, ink);
        canvas.drawCircle(const Offset(75, 65), 4.2, ink);
        canvas.drawArc(
          const Rect.fromLTWH(54, 72, 12, 8),
          math.pi,
          math.pi,
          false,
          stroke,
        );
      case 'shock_ahoge':
        // Wide O O eyes + exclamation
        canvas.drawCircle(const Offset(45, 64), 7, stroke);
        canvas.drawCircle(const Offset(75, 64), 7, stroke);
        canvas.drawCircle(const Offset(45, 64), 2.5, ink);
        canvas.drawCircle(const Offset(75, 64), 2.5, ink);
        canvas.drawLine(
          const Offset(98, 14),
          const Offset(94, 28),
          Paint()
            ..color = sticker.accent
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
      default:
        // Crisp oval cel eyes + thematic prop
        for (final cx in const [45.0, 75.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(cx, 64), width: 8.5, height: 15),
              const Radius.circular(5),
            ),
            ink,
          );
          canvas.drawCircle(Offset(cx - 1.5, 60), 2, fur);
        }
        if (sticker.id == 'cheer_flag') {
          canvas.drawLine(const Offset(95, 38), const Offset(95, 82), stroke);
          final flag = Path()
            ..moveTo(95, 38)
            ..lineTo(116, 47)
            ..lineTo(95, 56)
            ..close();
          canvas.drawPath(flag, accent);
          canvas.drawPath(flag, stroke..strokeWidth = 2);
        } else if (sticker.id == 'thinking_hmm') {
          final q = TextPainter(
            text: TextSpan(
              text: '?',
              style: TextStyle(
                color: sticker.accent,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          q.paint(canvas, const Offset(92, 12));
        } else if (sticker.id == 'ok_salute') {
          canvas.drawLine(const Offset(84, 46), const Offset(102, 38), stroke);
          canvas.drawCircle(const Offset(60, 77), 3.5, accent);
        } else if (sticker.id == 'tea_break') {
          final mug = RRect.fromRectAndRadius(
            const Rect.fromLTWH(48, 74, 24, 20),
            const Radius.circular(5),
          );
          canvas.drawRRect(mug, accent);
          canvas.drawRRect(mug, stroke..strokeWidth = 2.2);
        }
    }

    canvas.restore();
    if (sticker.id == 'peek_curious') {
      // Windowsill ledge across bottom for peeking pose
      canvas.drawLine(
        const Offset(6, 94),
        const Offset(114, 94),
        stroke..strokeWidth = 3.5,
      );
    }
    canvas.restore();
  }

  void _drawHeart(
    Canvas canvas,
    Offset center,
    double size,
    Paint fill,
    Paint border,
  ) {
    final p = Path()
      ..moveTo(center.dx, center.dy + size * 0.6)
      ..cubicTo(
        center.dx - size,
        center.dy - size * 0.2,
        center.dx - size * 0.5,
        center.dy - size,
        center.dx,
        center.dy - size * 0.35,
      )
      ..cubicTo(
        center.dx + size * 0.5,
        center.dy - size,
        center.dx + size,
        center.dy - size * 0.2,
        center.dx,
        center.dy + size * 0.6,
      )
      ..close();
    canvas.drawPath(p, fill);
    canvas.drawPath(p, border..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_StickerArtPainter oldDelegate) =>
      oldDelegate.sticker.id != sticker.id;
}

/// Ask for a name for the user's local favorite; cancellation does not write a favorite.
Future<String?> requestStickerTag(BuildContext context) {
  final text = PhoneL10n.of(context);
  var tag = '';
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(text.customStickerTagTitle),
        content: TextField(
          maxLength: 64,
          decoration: InputDecoration(hintText: text.customStickerTagHint),
          onChanged: (value) => setDialogState(() => tag = value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: tag.isEmpty
                ? null
                : () => Navigator.pop(dialogContext, tag),
            child: Text(text.addCustomSticker),
          ),
        ],
      ),
    ),
  );
}

/// Expandable drawer below the composer for sending built-in Cel stickers or user-imported stickers.
class StickerDrawerPanel extends StatefulWidget {
  const StickerDrawerPanel({
    super.key,
    required this.device,
    required this.onSendBuiltIn,
    required this.onSendCustom,
  });

  final DeviceController device;
  final ValueChanged<BuiltInSticker> onSendBuiltIn;
  final ValueChanged<Map<String, dynamic>> onSendCustom;

  @override
  State<StickerDrawerPanel> createState() => _StickerDrawerPanelState();
}

class _StickerDrawerPanelState extends State<StickerDrawerPanel> {
  int packTab = 0;

  Future<void> _importCustomSticker(
    BuildContext context,
    PhoneL10n text,
  ) async {
    final picked = await widget.device.pickImage('custom_sticker');
    final path = picked?['local_path'] as String?;
    if (path == null || path.isEmpty || !context.mounted) return;
    final tag = await requestStickerTag(context);
    if (tag == null || !context.mounted) return;
    await widget.device.invoke('add_sticker', {
      'local_path': path,
      'media_type': picked?['media_type'] ?? 'image/png',
      'tag': tag,
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = PhoneL10n.of(context);
    final colors = PhoneColors.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final customs = widget.device.customStickers;

    return Container(
      height: 248,
      margin: const EdgeInsets.fromLTRB(
        Cel.spaceSm,
        0,
        Cel.spaceSm,
        Cel.spaceXs,
      ),
      decoration: colors.celCard(notebook: true, radius: 22),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            // Scrolling keeps pack controls one row tall even with large system text.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _PackChip(
                    label: text.stickerPackBuiltIn,
                    selected: packTab == 0,
                    onTap: () => setState(() => packTab = 0),
                  ),
                  const SizedBox(width: 8),
                  _PackChip(
                    label: '${text.stickerPackCustom} (${customs.length})',
                    selected: packTab == 1,
                    onTap: () => setState(() => packTab = 1),
                  ),
                  if (packTab == 1)
                    TextButton.icon(
                      onPressed: () => _importCustomSticker(context, text),
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 18,
                      ),
                      label: Text(text.addCustomSticker),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: colors.outlinePaper),
          Expanded(
            child: packTab == 0
                ? GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 92,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                    itemCount: kBuiltInStickers.length,
                    itemBuilder: (context, index) {
                      final item = kBuiltInStickers[index];
                      return PressFeedback(
                        enabled: !widget.device.busy,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onSendBuiltIn(item);
                          },
                          child: Semantics(
                            button: true,
                            label: item.label(isZh),
                            child: CelStickerView(stickerId: item.id, size: 78),
                          ),
                        ),
                      );
                    },
                  )
                : customs.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(Cel.space),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            text.noCustomStickers,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.muted),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _importCustomSticker(context, text),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(text.addCustomSticker),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 92,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                    itemCount: customs.length,
                    itemBuilder: (context, index) {
                      final entry = customs[index];
                      final sid = entry['sticker_id'] as String? ?? '';
                      return PressFeedback(
                        enabled: !widget.device.busy,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onSendCustom(entry);
                          },
                          onLongPress: () async {
                            final remove = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(text.deleteSticker),
                                content: Text(
                                  text.deleteLocalStickerDescription,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(text.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(text.deleteSticker),
                                  ),
                                ],
                              ),
                            );
                            if (remove == true && sid.isNotEmpty) {
                              await widget.device.invoke('delete_sticker', {
                                'sticker_id': sid,
                              });
                            }
                          },
                          child: CelStickerView(
                            localPath: entry['local_path'] as String?,
                            caption: entry['tag'] as String?,
                            size: 78,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PackChip extends StatelessWidget {
  const _PackChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = PhoneColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.blushContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.blushSignal : colors.outlinePaper,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Cel.onBlushContainer : colors.muted,
          ),
        ),
      ),
    );
  }
}
