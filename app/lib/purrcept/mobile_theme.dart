/// Mobile reading surfaces and typography extend Cel without changing the shared WebUI grammar.
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Resolve the mobile palette from the system theme; state colors remain distinct from interaction.
class PhoneColors {
  PhoneColors.of(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color get canvas => dark ? MobileTokens.darkCanvas : Cel.canvas;
  Color get surface => dark ? MobileTokens.darkSurface : Cel.surface;
  Color get sunken => dark ? MobileTokens.darkSunken : Cel.sunken;
  Color get ink => dark ? MobileTokens.darkInk : Cel.ink;
  Color get muted => dark ? MobileTokens.darkMuted : Cel.muted;
  Color get brand => dark ? MobileTokens.darkBrand : Cel.brand;
  Color get active => dark ? MobileTokens.darkActive : Cel.active;
  Color get waiting => dark ? MobileTokens.darkWaiting : Cel.waiting;
  Color get failed => dark ? MobileTokens.darkFailed : Cel.failed;
  Color get hero => dark ? MobileTokens.darkHero : MobileTokens.hero;
}

/// Build one system-aware theme for onboarding, conversation and settings, with readable type scaling.
ThemeData phoneTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? MobileTokens.darkInk : Cel.ink;
  final surface = dark ? MobileTokens.darkSurface : Cel.surface;
  final brand = dark ? MobileTokens.darkBrand : Cel.brand;
  final base = ThemeData(useMaterial3: true, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? MobileTokens.darkCanvas : Cel.canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: brand,
      onPrimary: dark ? MobileTokens.darkCanvas : Cel.onBrand,
      surface: surface,
      onSurface: ink,
      error: dark ? MobileTokens.darkFailed : Cel.failed,
    ),
    textTheme: base.textTheme
        .copyWith(
          headlineLarge: TextStyle(
            fontSize: MobileTokens.displaySize,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          headlineMedium: TextStyle(
            fontSize: MobileTokens.titleSize,
            height: 1.2,
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
            height: MobileTokens.lineHeight,
            color: dark ? MobileTokens.darkMuted : Cel.muted,
          ),
        )
        .apply(fontFamily: 'Roboto'),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? MobileTokens.darkCanvas : Cel.canvas,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      indicatorColor: dark ? MobileTokens.darkHero : MobileTokens.hero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(MobileTokens.bubbleRadius),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: MobileTokens.bodySize,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MobileTokens.bubbleRadius),
        ),
      ),
    ),
  );
}
