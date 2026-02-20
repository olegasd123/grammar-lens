import 'package:flutter/material.dart';

/// GrammarLens color palette.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF60A5FA);
  static const primaryDark = Color(0xFF1D4ED8);
  static const secondary = Color(0xFF7C3AED);
  static const secondaryLight = Color(0xFFA78BFA);

  // ── Correction Types ───────────────────────────────────────────────────
  /// Grammar errors — red underline.
  static const errorRed = Color(0xFFEF4444);
  static const errorRedLight = Color(0xFFFEE2E2);

  /// Spelling errors — orange underline.
  static const warningOrange = Color(0xFFF59E0B);
  static const warningOrangeLight = Color(0xFFFEF3C7);

  /// Style suggestions — blue underline.
  static const styleBlue = Color(0xFF3B82F6);
  static const styleBlueLight = Color(0xFFDBEAFE);

  /// Punctuation errors — yellow underline.
  static const punctuationYellow = Color(0xFFEAB308);
  static const punctuationYellowLight = Color(0xFFFEF9C3);

  /// Accepted corrections — green.
  static const successGreen = Color(0xFF22C55E);
  static const successGreenLight = Color(0xFFDCFCE7);

  // ── Neutrals (Light Mode) ─────────────────────────────────────────────
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF4B5563);
  static const textTertiary = Color(0xFF9CA3AF);
  static const background = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF3F4F6);
  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);

  // ── Neutrals (Dark Mode) ──────────────────────────────────────────────
  static const darkTextPrimary = Color(0xFFF9FAFB);
  static const darkTextSecondary = Color(0xFFD1D5DB);
  static const darkTextTertiary = Color(0xFF6B7280);
  static const darkBackground = Color(0xFF111827);
  static const darkSurface = Color(0xFF1F2937);
  static const darkSurfaceVariant = Color(0xFF374151);
  static const darkBorder = Color(0xFF374151);
}
