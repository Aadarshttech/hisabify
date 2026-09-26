import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Background & Surfaces (Hisab Milau warm buttery cream canvas & warm card surface)
  static const Color background = Color(0xFFFEF9E7);      // Warm buttery cream canvas
  static const Color surface = Color(0xFFFFFDF7);         // Pure warm cream cards
  static const Color surfaceMuted = Color(0xFFFAF2DA);    // Warm cream badge/chip background
  static const Color border = Color(0xFFF3EAD3);          // Structural warm border
  static const Color borderSubtle = Color(0xFFF8F1DE);

  // Core Brand Palette (Deep Obsidian Charcoal & Precision Royal Sapphire)
  static const Color primary = Color(0xFF0F172A);          // Deep Slate / Charcoal
  static const Color primaryDark = Color(0xFF020617);
  static const Color brandAccent = Color(0xFF2563EB);      // Clean Royal Blue
  static const Color brandAccentLight = Color(0xFF3B82F6);

  // Financial Semantics (Restrained, high-contrast)
  static const Color positive = Color(0xFF059669);         // Forest Emerald (owed to you)
  static const Color positiveLight = Color(0xFFECFDF5);    // Soft sage pill background
  static const Color negative = Color(0xFFE11D48);         // Crimson Rose (you owe)
  static const Color negativeLight = Color(0xFFFFF1F2);    // Soft crimson pill background
  static const Color warning = Color(0xFFD97706);          // Deep Amber

  // Legacy mappings for backward compatibility
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF64748B);
  static const Color lightGrey = Color(0xFFE2E8F0);
  static const Color chipBackground = Color(0xFFF1F5F9);
  static const Color success = positive;
  static const Color error = negative;
  static const Color accent = brandAccent;
  static const Color indigo = Color(0xFF334155);

  // Typography Colors
  static const Color darkerText = Color(0xFF0F172A);       // High-contrast deep slate
  static const Color darkText = Color(0xFF334155);         // Body text
  static const Color lightText = Color(0xFF64748B);        // Secondary captions
  static const Color deactivatedText = Color(0xFF94A3B8);  // Placeholder

  // Card Gradients (Sophisticated Dark Obsidian Card & Clean Monochromes)
  static const LinearGradient heroCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1E293B),
    ],
  );

  static const LinearGradient balanceCardGradient = heroCardGradient;

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1E293B),
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E293B),
      Color(0xFF334155),
    ],
  );

  static const LinearGradient negativeCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF881337),
      Color(0xFF4C0519),
    ],
  );

  // Typography
  static const String fontName = 'Fredoka';

  static final TextTheme textTheme = TextTheme(
    displayLarge: const TextStyle(
      fontFamily: fontName,
      fontWeight: FontWeight.w700,
      fontSize: 36,
      letterSpacing: -0.6,
      color: darkerText,
    ),
    displayMedium: display1,
    headlineMedium: display1,
    headlineSmall: headline,
    titleLarge: title,
    titleMedium: subtitle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    titleSmall: subtitle,
    bodyMedium: body2,
    bodyLarge: body1,
    bodySmall: caption,
    labelLarge: const TextStyle(
      fontFamily: fontName,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      letterSpacing: 0.1,
      color: darkerText,
    ),
    labelMedium: caption.copyWith(fontSize: 12),
    labelSmall: caption,
  ).apply(
    fontFamily: fontName,
  );

  static const TextStyle display1 = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w700,
    fontSize: 32,
    letterSpacing: -0.6,
    color: darkerText,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    letterSpacing: -0.4,
    color: darkerText,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    letterSpacing: -0.2,
    color: darkerText,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    letterSpacing: -0.1,
    color: darkText,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    letterSpacing: 0,
    color: darkText,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    letterSpacing: 0,
    color: darkText,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontName,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    letterSpacing: 0.1,
    color: lightText,
  );

  // Shadow Styles (Subtle & clean)
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardShadowElevated => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.07),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> primaryGlow([Color color = primary]) => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}