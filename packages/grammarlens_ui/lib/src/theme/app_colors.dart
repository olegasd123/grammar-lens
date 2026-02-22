import 'package:flutter/material.dart';

/// GrammarLens color palette.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────
  static const primary = Color(0xFF3794FF);
  static const primaryLight = Color(0xFF3794FF);
  static const primaryDark = Color(0xFF005A9E);
  static const secondary = Color(0xFF2F7D95);
  static const secondaryLight = Color(0xFF5A9BB2);

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
  static const textPrimary = Color(0xFF1F1F1F);
  static const textSecondary = Color(0xFF4F4F4F);
  static const textTertiary = Color(0xFF767676);
  static const background = Color(0xFFF3F3F3);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF7F7F7);
  static const border = Color(0xFFE2E2E2);
  static const borderLight = Color(0xFFEBEBEB);

  // ── Neutrals (Dark Mode) ──────────────────────────────────────────────
  static const darkTextPrimary = Color(0xFFE6E6E6);
  static const darkTextSecondary = Color(0xFFB6B6B6);
  static const darkTextTertiary = Color(0xFF8C8C8C);
  static const darkBackground = Color(0xFF1E1E1E);
  static const darkSurface = Color(0xFF252526);
  static const darkSurfaceVariant = Color(0xFF2D2D30);
  static const darkBorder = Color(0xFF3C3C3C);
}
