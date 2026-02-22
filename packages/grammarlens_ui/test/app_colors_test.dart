import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammarlens_ui/grammarlens_ui.dart';

void main() {
  group('AppColors', () {
    test('correction type colors are distinct', () {
      final correctionColors = {
        AppColors.errorRed,
        AppColors.warningOrange,
        AppColors.styleBlue,
        AppColors.punctuationYellow,
      };
      expect(correctionColors, hasLength(4),
          reason: 'Each correction type must have a unique color');
    });

    test('light and dark text colors have sufficient contrast', () {
      // Light-mode text on light background
      expect(AppColors.textPrimary.computeLuminance(),
          lessThan(AppColors.background.computeLuminance()),
          reason: 'Light-mode text should be darker than background');

      // Dark-mode text on dark background
      expect(AppColors.darkTextPrimary.computeLuminance(),
          greaterThan(AppColors.darkBackground.computeLuminance()),
          reason: 'Dark-mode text should be lighter than background');
    });

    test('primary color is non-transparent', () {
      expect(AppColors.primary.a, 1.0);
    });
  });
}
