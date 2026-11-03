import 'package:femm_app/theme/petal_soft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Petal Soft locks Inter Air — no serif display stack', () {
    expect(PetalSoft.fontFamily, 'Inter');
    expect(PetalSoft.displayFontFamily, 'Inter');
    expect(PetalSoft.welcomeWeight, FontWeight.w500);
    expect(PetalSoft.welcomeSize, 28);
    expect(PetalSoft.wordmarkWeight, FontWeight.w500);
    expect(PetalSoft.wordmarkSize, 16);
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
}
