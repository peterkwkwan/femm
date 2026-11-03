import 'package:femm_app/theme/petal_soft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Petal Soft locks Inter Air UI + Cormorant Soft display wordmark', () {
    expect(PetalSoft.fontFamily, 'Inter');
    expect(PetalSoft.displayFontFamily, 'Cormorant Garamond');
    expect(PetalSoft.welcomeWeight, FontWeight.w500);
    expect(PetalSoft.welcomeSize, 28);
    expect(PetalSoft.wordmarkWeight, FontWeight.w600);
    expect(PetalSoft.wordmarkSize, 16);
    expect(PetalSoft.wordmarkStyle, FontStyle.italic);
    expect(PetalSoft.majesticWordmarkSize, 44);
    expect(PetalSoft.majesticWordmarkWeight, FontWeight.w600);
    expect(PetalSoft.majesticWordmarkStyle, FontStyle.italic);
  });

  test('theme applies Inter across text + buttons; app bar title Cormorant Soft',
      () {
    final theme = PetalSoft.theme();
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.textTheme.headlineSmall?.fontFamily, 'Inter');
    expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w500);
    expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Cormorant Garamond');
    expect(theme.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w600);
    expect(theme.appBarTheme.titleTextStyle?.fontStyle, FontStyle.italic);

    final filled = theme.filledButtonTheme.style?.textStyle
        ?.resolve(const <WidgetState>{});
    expect(filled?.fontFamily, 'Inter');
    expect(filled?.fontWeight, FontWeight.w600);
  });

  test('nav wordmark style is Cormorant Soft italic (Dawn Mist face, quieter)',
      () {
    final style = PetalSoft.wordmarkTextStyle();
    expect(style.fontFamily, 'Cormorant Garamond');
    expect(style.fontSize, 16);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.fontStyle, FontStyle.italic);
    expect(
      style.letterSpacing,
      PetalSoft.letterSpacingEm(16, PetalSoft.wordmarkTrackingEm),
    );
  });

  test('majestic wordmark style is Cormorant Soft italic', () {
    final style = PetalSoft.majesticWordmarkTextStyle();
    expect(style.fontFamily, 'Cormorant Garamond');
    expect(style.fontSize, 44);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.fontStyle, FontStyle.italic);
    expect(
      style.letterSpacing,
      PetalSoft.letterSpacingEm(44, PetalSoft.majesticWordmarkTrackingEm),
    );
  });
}
