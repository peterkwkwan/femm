import 'package:flutter/material.dart';

/// Locked Petal Soft visual direction (Path A mockups).
///
/// Canvas tokens: blush canvas, rose accent, serif display headlines.
abstract final class PetalSoft {
  static const Color bg = Color(0xFFF8EFEA);
  static const Color surface = Color(0xFFFFF9F6);
  static const Color ink = Color(0xFF2A1F1C);
  static const Color muted = Color(0xFF7A6560);
  static const Color accent = Color(0xFFB85C5C);
  static const Color accentSoft = Color(0xFFF0D9D4);

  /// Platform serif (Android → Noto/Droid Serif) for display headlines.
  static const String displayFontFamily = 'serif';

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
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: ink.withValues(alpha: 0.10),
    );

    final textTheme = base.textTheme.apply(
      bodyColor: ink,
      displayColor: ink,
    );

    TextStyle display(TextStyle? style, {double? size, FontWeight? weight}) {
      return (style ?? const TextStyle()).copyWith(
        fontFamily: displayFontFamily,
        fontSize: size,
        fontWeight: weight ?? FontWeight.w600,
        color: ink,
        height: 1.15,
      );
    }

    return base.copyWith(
      textTheme: textTheme.copyWith(
        displaySmall: display(textTheme.displaySmall, size: 32),
        headlineMedium: display(textTheme.headlineMedium, size: 26),
        headlineSmall: display(textTheme.headlineSmall, size: 22),
        titleLarge: display(textTheme.titleLarge, size: 20),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: ink, height: 1.45),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: ink, height: 1.45),
        bodySmall: textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
        labelLarge: textTheme.labelLarge?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: displayFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: accent.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: ink.withValues(alpha: 0.18)),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent,
        disabledColor: surface,
        secondarySelectedColor: accent,
        labelStyle: const TextStyle(color: ink, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 13),
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
