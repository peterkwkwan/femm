import 'package:flutter/material.dart';

/// Locked Petal Soft visual direction (Path A mockups).
///
/// Canvas tokens: blush canvas, rose accent, Inter Air typography
/// (Inter throughout — lighter weights + airier tracking).
abstract final class PetalSoft {
  static const Color bg = Color(0xFFF8EFEA);
  static const Color surface = Color(0xFFFFF9F6);
  static const Color ink = Color(0xFF2A1F1C);
  static const Color muted = Color(0xFF7A6560);
  static const Color accent = Color(0xFFB85C5C);
  static const Color accentSoft = Color(0xFFF0D9D4);
  /// Mid bloom layer in the locked Calmness mark.
  static const Color blush = Color(0xFFE8C4BC);

  /// Inter Air — single sans for display + UI (replaces platform serif).
  static const String fontFamily = 'Inter';

  /// Alias kept for call sites that previously targeted serif display.
  static const String displayFontFamily = fontFamily;

  /// Inter Air Welcome: medium, larger, −0.03em tracking.
  static const double welcomeSize = 28;
  static const FontWeight welcomeWeight = FontWeight.w500;
  static const double welcomeTrackingEm = -0.03;

  /// Inter Air wordmark (femm): medium, 0.04em tracking.
  static const double wordmarkSize = 16;
  static const FontWeight wordmarkWeight = FontWeight.w500;
  static const double wordmarkTrackingEm = 0.04;

  static double letterSpacingEm(double size, double em) => size * em;

  static TextStyle welcomeTextStyle({Color color = ink}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: welcomeSize,
      fontWeight: welcomeWeight,
      letterSpacing: letterSpacingEm(welcomeSize, welcomeTrackingEm),
      height: 1.1,
      color: color,
    );
  }

  static TextStyle wordmarkTextStyle({
    double size = wordmarkSize,
    Color color = ink,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: wordmarkWeight,
      letterSpacing: letterSpacingEm(size, wordmarkTrackingEm),
      height: 1,
      color: color,
    );
  }

  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: accent,
    onPrimary: Colors.white,
    secondary: accentSoft,
    onSecondary: ink,
    error: Color(0xFFB3261E),
    onError: Colors.white,
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: muted,
    outline: Color(0x4D2A1F1C),
    outlineVariant: Color(0x292A1F1C),
    surfaceContainerHighest: accentSoft,
    primaryContainer: accentSoft,
    onPrimaryContainer: ink,
  );

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: ink.withValues(alpha: 0.10),
    );

    final textTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: ink,
      displayColor: ink,
    );

    TextStyle display(TextStyle? style, {double? size, FontWeight? weight}) {
      final resolvedSize = size ?? style?.fontSize ?? 24;
      return (style ?? const TextStyle()).copyWith(
        fontFamily: fontFamily,
        fontSize: resolvedSize,
        // Inter Air: medium display, not heavy serif.
        fontWeight: weight ?? FontWeight.w500,
        letterSpacing: letterSpacingEm(resolvedSize, welcomeTrackingEm),
        color: ink,
        height: 1.15,
      );
    }

    return base.copyWith(
      textTheme: textTheme.copyWith(
        displaySmall: display(textTheme.displaySmall, size: 32),
        headlineMedium: display(textTheme.headlineMedium, size: 26),
        headlineSmall: display(textTheme.headlineSmall, size: 22),
        titleLarge: display(
          textTheme.titleLarge,
          size: 20,
          weight: FontWeight.w500,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontFamily: fontFamily,
          color: ink,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          fontFamily: fontFamily,
          color: ink,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontFamily: fontFamily,
          color: ink,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontFamily: fontFamily,
          color: ink,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontFamily: fontFamily,
          color: muted,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontFamily: fontFamily,
          color: accent,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: wordmarkTextStyle(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: accent.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white70,
          // Use a finite width — Size.fromHeight(48) is infinite-wide and
          // asserts when a FilledButton sits in a Row (match upsell actions).
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: ink.withValues(alpha: 0.18)),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent,
        disabledColor: surface,
        secondarySelectedColor: accent,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: ink,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: const StadiumBorder(),
        side: BorderSide(color: ink.withValues(alpha: 0.18)),
        checkmarkColor: Colors.white,
        showCheckmark: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: ink.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ink.withValues(alpha: 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ink.withValues(alpha: 0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: ink.withValues(alpha: 0.35)),
      ),
    );
  }
}
