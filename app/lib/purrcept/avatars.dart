/// Custom & Cel-preset avatars for both the companion Bot and the user, plus the Avatar Studio sheet.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'device.dart';
import 'experience.dart';
import 'l10n/app_localizations.dart';
import 'mascot.dart';
import 'mobile_theme.dart';
import 'press_feedback.dart';
import 'tokens.dart';

/// Built-in Cel v0.4 vector avatar presets so users can personalize immediately or pick album photos.
class AvatarPreset {
  const AvatarPreset({
    required this.id,
    required this.zhLabel,
    required this.enLabel,
    required this.bg,
    required this.accent,
  });
  final String id;
  final String zhLabel;
  final String enLabel;
  final Color bg;
  final Color accent;
}

const kAvatarPresets = <AvatarPreset>[
  AvatarPreset(
    id: 'preset:cat_classic',
    zhLabel: '晴空白猫',
    enLabel: 'Sky Cat',
    bg: Cel.brandContainer,
    accent: Cel.brandFill,
  ),
  AvatarPreset(
    id: 'preset:cat_sakura',
    zhLabel: '樱桃呆毛',
    enLabel: 'Sakura',
    bg: Cel.blushContainer,
    accent: Cel.blushSignal,
  ),
  AvatarPreset(
    id: 'preset:cat_scholar',
    zhLabel: '学园眼镜',
    enLabel: 'Scholar',
    bg: Cel.activeContainer,
    accent: Cel.active,
  ),
  AvatarPreset(
    id: 'preset:star_ribbon',
    zhLabel: '星结徽章',
    enLabel: 'Starlight',
    bg: Cel.tapeContainer,
    accent: Cel.tapeSignal,
  ),
  AvatarPreset(
    id: 'preset:warm_tea',
    zhLabel: '暖茶手账',
    enLabel: 'Warm Tea',
    bg: Cel.paperSunken,
    accent: Cel.onTapeContainer,
  ),
  AvatarPreset(
    id: 'preset:berry_headphones',
    zhLabel: '律动耳机',
    enLabel: 'Headset',
    bg: Cel.pausedContainer,
    accent: Cel.pausedSignal,
  ),
];

/// Renders a framed Cel avatar for either the companion Bot or the user.
class CompanionAvatar extends StatelessWidget {
  const CompanionAvatar({
    super.key,
    required this.isBot,
    this.avatarSource,
    this.fallbackName,
    this.phase = CompanionPhase.ready,
    this.size = MobileTokens.chatAvatarSize,
    this.showStatusDot = false,
    this.online = false,
    this.onTap,
  });

  final bool isBot;
  final String? avatarSource;
  final String? fallbackName;
  final CompanionPhase phase;
  final double size;
  final bool showStatusDot;
  final bool online;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = PhoneColors.of(context);
    final radius = size * 0.34;
    final core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isBot ? colors.hero : colors.blushContainer,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.ink, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors.celShadow,
            offset: const Offset(1.5, 2),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildInner(context, colors),
    );

    final badged = !showStatusDot
        ? core
        : Stack(
            clipBehavior: Clip.none,
            children: [
              core,
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: size * 0.3,
                  height: size * 0.3,
                  decoration: BoxDecoration(
                    color: !online
                        ? colors.muted
                        : (phase == CompanionPhase.thinking ||
                              phase == CompanionPhase.acting ||
                              phase == CompanionPhase.processing)
                        ? colors.activeSignal
                        : Cel.successSignal,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                ),
              ),
            ],
          );

    if (onTap == null) return badged;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: badged,
    );
  }

  Widget _buildInner(BuildContext context, PhoneColors colors) {
    final src = avatarSource?.trim();
    if (src != null && src.isNotEmpty) {
      if (src.startsWith('preset:')) {
        final preset = kAvatarPresets.firstWhere(
          (item) => item.id == src,
          orElse: () => kAvatarPresets.first,
        );
        return ColoredBox(
          color: preset.bg,
          child: CustomPaint(
            painter: _PresetAvatarPainter(presetId: preset.id, accent: preset.accent),
          ),
        );
      }
      if (src.startsWith('data:image/')) {
        final comma = src.indexOf(',');
        if (comma > 0) {
          try {
            final bytes = base64Decode(src.substring(comma + 1));
            return Image.memory(bytes, fit: BoxFit.cover);
          } catch (_) {}
        }
      } else {
        final file = File(src);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _defaultInner(colors),
          );
        }
      }
    }
    return _defaultInner(colors);
  }

  Widget _defaultInner(PhoneColors colors) {
    if (isBot) {
      return Padding(
        padding: EdgeInsets.only(top: size * 0.08),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          child: CompanionMascot(phase: phase),
        ),
      );
    }
    final label = (fallbackName ?? '').trim();
    final rune = label.isNotEmpty ? String.fromCharCode(label.runes.first) : '✦';
    return ColoredBox(
      color: colors.tapeContainer,
      child: Center(
        child: Text(
          rune,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: Cel.onTapeContainer,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _PresetAvatarPainter extends CustomPainter {
  const _PresetAvatarPainter({required this.presetId, required this.accent});
  final String presetId;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final fur = Paint()..color = MobileTokens.fur;
    final shade = Paint()..color = MobileTokens.furShade;
    final ink = Paint()
      ..color = Cel.ink
      ..style = PaintingStyle.fill;
    final strokeInk = Paint()
      ..color = Cel.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final accentPaint = Paint()..color = accent;

    if (presetId == 'preset:star_ribbon') {
      // Four-point academy star emblem + ribbon tails
      final ribbon = Path()
        ..moveTo(36, 62)
        ..lineTo(24, 88)
        ..lineTo(44, 78)
        ..close()
        ..moveTo(64, 62)
        ..lineTo(76, 88)
        ..lineTo(56, 78)
        ..close();
      canvas.drawPath(ribbon, Paint()..color = Cel.blushSignal);
      final star = Path()
        ..moveTo(50, 14)
        ..quadraticBezierTo(54, 42, 84, 48)
        ..quadraticBezierTo(54, 54, 50, 82)
        ..quadraticBezierTo(46, 54, 16, 48)
        ..quadraticBezierTo(46, 42, 50, 14)
        ..close();
      canvas.drawPath(star, fur);
      canvas.drawPath(star, strokeInk);
      canvas.drawCircle(const Offset(50, 48), 7, accentPaint);
      canvas.restore();
      return;
    }

    if (presetId == 'preset:warm_tea') {
      // Cozy notebook teacup with rising steam heart
      final cup = RRect.fromRectAndCorners(
        const Rect.fromLTWH(24, 44, 46, 36),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
        bottomLeft: const Radius.circular(18),
        bottomRight: const Radius.circular(18),
      );
      canvas.drawArc(
        const Rect.fromLTWH(60, 50, 20, 20),
        -1.2,
        2.5,
        false,
        strokeInk,
      );
      canvas.drawRRect(cup, fur);
      canvas.drawRRect(cup, strokeInk);
      canvas.drawOval(const Rect.fromLTWH(28, 47, 38, 8), accentPaint);
      final steam = Paint()
        ..color = Cel.blushSignal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(40, 35)
          ..quadraticBezierTo(36, 26, 42, 18)
          ..moveTo(54, 35)
          ..quadraticBezierTo(58, 26, 52, 18),
        steam,
      );
      canvas.restore();
      return;
    }

    // Cat silhouette base for classic / sakura / scholar / berry_headphones
    final leftEar = Path()
      ..moveTo(22, 52)
      ..quadraticBezierTo(16, 16, 26, 18)
      ..quadraticBezierTo(38, 22, 44, 38)
      ..close();
    final rightEar = Path()
      ..moveTo(78, 52)
      ..quadraticBezierTo(84, 16, 74, 18)
      ..quadraticBezierTo(62, 22, 56, 38)
      ..close();
    canvas.drawPath(leftEar, fur);
    canvas.drawPath(rightEar, fur);
    canvas.drawPath(
      Path()
        ..moveTo(26, 25)
        ..lineTo(36, 38)
        ..lineTo(25, 42)
        ..close(),
      shade,
    );
    canvas.drawPath(
      Path()
        ..moveTo(74, 25)
        ..lineTo(64, 38)
        ..lineTo(75, 42)
        ..close(),
      shade,
    );

    canvas.drawOval(const Rect.fromLTWH(16, 32, 68, 62), fur);
    // Blush cheeks
    final blush = Paint()..color = MobileTokens.blush;
    canvas.drawOval(const Rect.fromLTWH(24, 67, 13, 6.5), blush);
    canvas.drawOval(const Rect.fromLTWH(63, 67, 13, 6.5), blush);

    // Eyes
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(35, 53, 7, 13),
        const Radius.circular(4),
      ),
      presetId == 'preset:cat_classic' ? accentPaint : ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(58, 53, 7, 13),
        const Radius.circular(4),
      ),
      presetId == 'preset:cat_classic' ? accentPaint : ink,
    );

    if (presetId == 'preset:cat_sakura') {
      // Cute sakura hairpin on right ear
      for (int i = 0; i < 5; i++) {
        canvas.save();
        canvas.translate(72, 34);
        canvas.rotate(i * 1.2566);
        canvas.drawOval(const Rect.fromLTWH(-3.5, -10, 7, 9), accentPaint);
        canvas.restore();
      }
      canvas.drawCircle(
        const Offset(72, 34),
        3,
        Paint()..color = Cel.tapeSignal,
      );
    } else if (presetId == 'preset:cat_scholar') {
      // Round academy glasses
      final glasses = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8;
      canvas.drawCircle(const Offset(38.5, 59.5), 10, glasses);
      canvas.drawCircle(const Offset(61.5, 59.5), 10, glasses);
      canvas.drawLine(const Offset(48.5, 59.5), const Offset(51.5, 59.5), glasses);
    } else if (presetId == 'preset:berry_headphones') {
      // Anime headband & earcups
      final band = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(const Rect.fromLTWH(13, 22, 74, 64), 3.35, 2.72, false, band);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(9, 48, 10, 22),
          const Radius.circular(5),
        ),
        accentPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(81, 48, 10, 22),
          const Radius.circular(5),
        ),
        accentPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PresetAvatarPainter oldDelegate) =>
      oldDelegate.presetId != presetId || oldDelegate.accent != accent;
}

/// Interactive bottom sheet allowing independent customization of Bot & User avatars and nickname.
Future<void> showAvatarStudioSheet({
  required BuildContext context,
  required DeviceController device,
  int initialTab = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _AvatarStudioBody(
      device: device,
      initialTab: initialTab,
    ),
  );
}

class _AvatarStudioBody extends StatefulWidget {
  const _AvatarStudioBody({required this.device, required this.initialTab});
  final DeviceController device;
  final int initialTab;

  @override
  State<_AvatarStudioBody> createState() => _AvatarStudioBodyState();
}

class _AvatarStudioBodyState extends State<_AvatarStudioBody> {
  late int tab = widget.initialTab;
  late final TextEditingController nameCtrl = TextEditingController(
    text: widget.device.userName ?? '',
  );

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = PhoneL10n.of(context);
    final colors = PhoneColors.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    return AnimatedBuilder(
      animation: widget.device,
      builder: (context, _) {
        final botName =
            widget.device.experience.name ?? text.companionFallback;
        final currentAvatar = tab == 0
            ? widget.device.botAvatar
            : widget.device.userAvatar;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: Cel.space * 1.25,
              right: Cel.space * 1.25,
              bottom:
                  MediaQuery.viewInsetsOf(context).bottom + Cel.space * 1.25,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text.avatarStudioTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text.avatarStudioSubtitle,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: MobileTokens.labelSize,
                    ),
                  ),
                  const SizedBox(height: Cel.space),

                  // Live side-by-side chat preview card
                  Container(
                    padding: const EdgeInsets.all(Cel.spaceSm),
                    decoration: colors.celCard(notebook: true, radius: 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CompanionAvatar(
                              isBot: true,
                              avatarSource: widget.device.botAvatar,
                              phase: widget.device.experience.phase,
                              size: 38,
                              showStatusDot: true,
                              online: widget.device.online,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: colors.celBubble(fromUser: false),
                                child: Text(
                                  '$botName · ${text.activityReady}',
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: colors.celBubble(fromUser: true),
                                child: Text(
                                  nameCtrl.text.trim().isNotEmpty
                                      ? nameCtrl.text.trim()
                                      : text.you,
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            CompanionAvatar(
                              isBot: false,
                              avatarSource: widget.device.userAvatar,
                              fallbackName: nameCtrl.text.trim().isNotEmpty
                                  ? nameCtrl.text.trim()
                                  : text.you,
                              size: 38,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Cel.space),

                  // Role switcher: Companion vs Me
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.sunken,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colors.outline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SegmentPill(
                            label: text.companionAvatarTab,
                            selected: tab == 0,
                            onTap: () => setState(() => tab = 0),
                          ),
                        ),
                        Expanded(
                          child: _SegmentPill(
                            label: text.userAvatarTab,
                            selected: tab == 1,
                            onTap: () => setState(() => tab = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Cel.space),

                  // Album pick + Reset buttons
                  Wrap(
                    spacing: Cel.spaceSm,
                    runSpacing: Cel.spaceXs,
                    children: [
                      PressFeedback(
                        enabled: !widget.device.busy,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final purpose = tab == 0
                                ? 'bot_avatar'
                                : 'user_avatar';
                            final picked = await widget.device.pickImage(
                              purpose,
                            );
                            final path = picked?['local_path'] as String?;
                            if (path != null && path.isNotEmpty) {
                              await widget.device.invoke('set_profile', {
                                purpose: path,
                              });
                            }
                          },
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: Text(text.pickAlbumAvatar),
                        ),
                      ),
                      if (currentAvatar != null)
                        OutlinedButton.icon(
                          onPressed: () => widget.device.invoke('set_profile', {
                            tab == 0 ? 'bot_avatar' : 'user_avatar': null,
                          }),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(text.resetDefaultAvatar),
                        ),
                    ],
                  ),
                  const SizedBox(height: Cel.space),

                  Text(
                    text.presetAvatarsTitle,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: Cel.spaceXs),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final preset in kAvatarPresets)
                        _PresetAvatarTile(
                          preset: preset,
                          label: isZh ? preset.zhLabel : preset.enLabel,
                          selected: currentAvatar == preset.id,
                          onTap: () => widget.device.invoke('set_profile', {
                            tab == 0 ? 'bot_avatar' : 'user_avatar': preset.id,
                          }),
                        ),
                    ],
                  ),

                  if (tab == 1) ...[
                    const SizedBox(height: Cel.space),
                    TextField(
                      controller: nameCtrl,
                      maxLength: 24,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: text.userNicknameLabel,
                        hintText: text.userNicknameHint,
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: Cel.spaceSm),
                    FilledButton(
                      onPressed: () async {
                        await widget.device.invoke('set_profile', {
                          'user_name': nameCtrl.text.trim(),
                        });
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(text.saveProfile),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
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
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: MobileTokens.effects,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? Border.all(color: colors.brandSignal, width: 1.2)
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.brand : colors.muted,
          ),
        ),
      ),
    );
  }
}

class _PresetAvatarTile extends StatelessWidget {
  const _PresetAvatarTile({
    required this.preset,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final AvatarPreset preset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = PhoneColors.of(context);
    return PressFeedback(
      enabled: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? colors.brandContainer : colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colors.brand : colors.outline,
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompanionAvatar(
                isBot: true,
                avatarSource: preset.id,
                size: 46,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.brand : colors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
