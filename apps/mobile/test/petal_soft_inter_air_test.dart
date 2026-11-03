import 'package:femm_app/theme/petal_soft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Petal Soft locks Inter Air UI + Cormorant Soft display wordmark', () {
    expect(PetalSoft.fontFamily, 'Inter');
    expect(PetalSoft.displayFontFamily, 'Cormorant Garamond');
    expect(PetalSoft.welcomeWeight, FontWeight.w500);
    expect(PetalSoft.welcomeSize, 28);
    expect(PetalSoft.wordmarkWeight, FontWeight.w500);
    expect(PetalSoft.wordmarkSize, 16);
    expect(PetalSoft.majesticWordmarkSize, 44);
    expect(PetalSoft.majesticWordmarkWeight, FontWeight.w600);
    expect(PetalSoft.majesticWordmarkStyle, FontStyle.italic);
  });

  test('theme applies Inter across text + buttons', () {
    final theme = PetalSoft.theme();
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.textTheme.headlineSmall?.fontFamily, 'Inter');
    expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w500);
    expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Inter');
    expect(theme.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w500);

    final filled = theme.filledButtonTheme.style?.textStyle
        ?.resolve(const <WidgetState>{});
    expect(filled?.fontFamily, 'Inter');
    expect(filled?.fontWeight, FontWeight.w600);
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
