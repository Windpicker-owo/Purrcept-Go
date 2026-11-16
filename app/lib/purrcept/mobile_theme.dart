/// Mobile reading surfaces, Cel v0.4 hard-edge shadows, asymmetric bubbles, and atmosphere backdrop.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Resolve the Cel v0.4 Clear Academy × Warm Notebook palette from system brightness.
class PhoneColors {
  PhoneColors.of(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;

  Color get canvas => dark ? MobileTokens.darkCanvas : Cel.canvas;
  Color get surface => dark ? MobileTokens.darkSurface : Cel.surface;
  Color get sunken => dark ? MobileTokens.darkSunken : Cel.sunken;
  Color get paper => dark ? MobileTokens.darkPaper : Cel.paper;
  Color get ink => dark ? MobileTokens.darkInk : Cel.ink;
  Color get inkSecondary => dark ? MobileTokens.darkMuted : Cel.inkSecondary;
  Color get muted => dark ? MobileTokens.darkMuted : Cel.muted;
  Color get outline => dark ? MobileTokens.darkOutline : Cel.outline;
  Color get outlineSubtle =>
      dark ? MobileTokens.darkOutline : Cel.outlineSubtle;
  Color get outlinePaper => dark ? MobileTokens.darkOutline : Cel.outlinePaper;
  Color get celShadow => dark ? MobileTokens.darkCelShadow : Cel.celShadowSky;
  Color get celShadowPaper =>
      dark ? MobileTokens.darkCelShadow : Cel.celShadowPaper;
  Color get brand => dark ? MobileTokens.darkBrand : Cel.brand;
  Color get brandFill => dark ? MobileTokens.darkBrand : Cel.brandFill;
  Color get brandSignal => dark ? MobileTokens.darkBrand : Cel.brandSignal;
  Color get brandContainer => dark ? MobileTokens.darkHero : Cel.brandContainer;
  Color get onBrand => dark ? MobileTokens.darkCanvas : Cel.onBrand;
  Color get blushSignal => Cel.blushSignal;
  Color get blushContainer =>
      dark ? MobileTokens.darkBlushContainer : Cel.blushContainer;
  Color get tapeSignal => Cel.tapeSignal;
  Color get tapeContainer =>
      dark ? MobileTokens.darkTapeContainer : Cel.tapeContainer;
  Color get active => dark ? MobileTokens.darkActive : Cel.active;
  Color get activeSignal => dark ? MobileTokens.darkActive : Cel.activeSignal;
  Color get activeContainer =>
      dark ? MobileTokens.darkActiveContainer : Cel.activeContainer;
  Color get success => dark ? MobileTokens.darkActive : Cel.success;
  Color get successContainer =>
      dark ? MobileTokens.darkSuccessContainer : Cel.successContainer;
  Color get waiting => dark ? MobileTokens.darkWaiting : Cel.waiting;
  Color get waitingContainer =>
      dark ? MobileTokens.darkTapeContainer : Cel.waitingContainer;
  Color get failed => dark ? MobileTokens.darkFailed : Cel.failed;
  Color get failedContainer =>
      dark ? MobileTokens.darkBlushContainer : Cel.failedContainer;
  Color get hero => dark ? MobileTokens.darkHero : MobileTokens.hero;

  /// Crisp 1.5dp cel border + zero-blur hard shadow for panels and cards.
  BoxDecoration celCard({
    bool notebook = false,
    Color? fill,
    Color? border,
    double radius = MobileTokens.panelRadius,
    bool elevated = true,
  }) => BoxDecoration(
    color: fill ?? (notebook ? paper : surface),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: border ?? (notebook ? outlinePaper : outline),
      width: MobileTokens.borderWidth,
    ),
    boxShadow: elevated
        ? [
            BoxShadow(
              color: notebook ? celShadowPaper : celShadow,
              offset: const Offset(
                MobileTokens.celShadowDx,
                MobileTokens.celShadowDy,
              ),
              blurRadius: 0,
            ),
          ]
        : const [],
  );

  /// Asymmetric anime speech-bubble geometry with crisp outline and tactile cel shadow.
  BoxDecoration celBubble({required bool fromUser}) => BoxDecoration(
    color: fromUser ? hero : surface,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(
        fromUser ? MobileTokens.bubbleRadius : MobileTokens.bubbleSharpRadius,
      ),
      topRight: Radius.circular(
        fromUser ? MobileTokens.bubbleSharpRadius : MobileTokens.bubbleRadius,
      ),
      bottomLeft: const Radius.circular(MobileTokens.bubbleRadius),
      bottomRight: const Radius.circular(MobileTokens.bubbleRadius),
    ),
    border: Border.all(
      color: fromUser
          ? (dark
                ? MobileTokens.darkBrand.withValues(alpha: 0.55)
                : Cel.brandSignal.withValues(alpha: 0.65))
          : outline,
      width: MobileTokens.borderWidth,
    ),
    boxShadow: [
      BoxShadow(color: celShadow, offset: const Offset(2, 3), blurRadius: 0),
    ],
  );
}

/// Subtle Clear Academy sky × peach radial glow with upper-right halftone dots.
class CelAtmosphereBackdrop extends StatelessWidget {
  const CelAtmosphereBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = PhoneColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.canvas),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: CustomPaint(painter: _AtmospherePainter(dark: colors.dark)),
          ),
          // Tiles paint ink on their nearest Material, above the atmosphere artwork.
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}

/// A decorated card whose children paint ink above its opaque background and border.
class PhoneCard extends StatelessWidget {
  const PhoneCard({
    super.key,
    required this.decoration,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final BoxDecoration decoration;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: decoration,
    child: Material(
      type: MaterialType.transparency,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final skyCenter = Offset(size.width * 0.08, size.height * 0.04);
    final skyRadius = math.max(size.width, size.height) * 0.55;
    final skyPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (dark ? const Color(0xFF1A3152) : Cel.atmosphereSky).withValues(
            alpha: dark ? 0.45 : 0.85,
          ),
          (dark ? const Color(0xFF1A3152) : Cel.atmosphereSky).withValues(
            alpha: 0,
          ),
        ],
      ).createShader(Rect.fromCircle(center: skyCenter, radius: skyRadius));
    canvas.drawCircle(skyCenter, skyRadius, skyPaint);

    final peachCenter = Offset(size.width * 0.94, size.height * 0.06);
    final peachRadius = math.max(size.width, size.height) * 0.48;
    final peachPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (dark ? const Color(0xFF35222B) : Cel.atmospherePeach).withValues(
            alpha: dark ? 0.36 : 0.82,
          ),
          (dark ? const Color(0xFF35222B) : Cel.atmospherePeach).withValues(
            alpha: 0,
          ),
        ],
      ).createShader(Rect.fromCircle(center: peachCenter, radius: peachRadius));
    canvas.drawCircle(peachCenter, peachRadius, peachPaint);

    // Subtle academy halftone dot accents in the top-right corner
    final dotPaint = Paint()
      ..color = (dark ? MobileTokens.darkOutline : Cel.brandContainer)
          .withValues(alpha: dark ? 0.35 : 0.65);
    const spacing = 16.0;
    final startX = size.width * 0.58;
    final maxY = math.min(size.height * 0.24, 180.0);
    for (double y = 12; y < maxY; y += spacing) {
      for (double x = startX; x < size.width - 8; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.35, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      oldDelegate.dark != dark;
}

/// Build one system-aware Cel v0.4 theme for onboarding, social conversation and settings.
ThemeData phoneTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? MobileTokens.darkInk : Cel.ink;
  final surface = dark ? MobileTokens.darkSurface : Cel.surface;
  final outline = dark ? MobileTokens.darkOutline : Cel.outline;
  final brand = dark ? MobileTokens.darkBrand : Cel.brandFill;
  final base = ThemeData(useMaterial3: true, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? MobileTokens.darkCanvas : Cel.canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: brand,
      onPrimary: dark ? MobileTokens.darkCanvas : Cel.onBrand,
      surface: surface,
      onSurface: ink,
      outline: outline,
      error: dark ? MobileTokens.darkFailed : Cel.failed,
    ),
    textTheme: base.textTheme
        .copyWith(
          headlineLarge: TextStyle(
            fontSize: MobileTokens.displaySize,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: ink,
          ),
          headlineMedium: TextStyle(
            fontSize: MobileTokens.titleSize,
            height: 1.24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: ink,
          ),
          titleMedium: TextStyle(
            fontSize: MobileTokens.bodySize,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          bodyLarge: TextStyle(
            fontSize: MobileTokens.bodySize,
            height: MobileTokens.lineHeight,
            color: ink,
          ),
          bodyMedium: TextStyle(
            fontSize: MobileTokens.bodySize,
            height: MobileTokens.lineHeight,
            color: ink,
          ),
          labelMedium: TextStyle(
            fontSize: MobileTokens.labelSize,
            height: 1.38,
            fontWeight: FontWeight.w600,
            color: dark ? MobileTokens.darkMuted : Cel.muted,
          ),
        )
        .apply(fontFamily: 'Roboto'),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 66,
      indicatorColor: dark ? MobileTokens.darkHero : Cel.brandContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: dark ? MobileTokens.darkBrand : Cel.brandSignal,
          width: 1.2,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: MobileTokens.labelSize,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? (dark ? MobileTokens.darkBrand : Cel.brand)
              : (dark ? MobileTokens.darkMuted : Cel.muted),
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: outline, width: MobileTokens.borderWidth),
        borderRadius: BorderRadius.circular(MobileTokens.bubbleRadius),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: brand, width: 2),
        borderRadius: BorderRadius.circular(MobileTokens.bubbleRadius),
      ),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: outline, width: MobileTokens.borderWidth),
        borderRadius: BorderRadius.circular(MobileTokens.bubbleRadius),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: brand,
        foregroundColor: dark ? MobileTokens.darkCanvas : Cel.onBrand,
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: MobileTokens.bodySize,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: dark ? MobileTokens.darkOutline : Cel.brandPressed,
            width: 1.5,
          ),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 46),
        foregroundColor: ink,
        side: BorderSide(color: outline, width: MobileTokens.borderWidth),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MobileTokens.heroRadius),
        ),
      ),
    ),
  );
}
