import 'package:flutter/material.dart';

// Calm, clinical-technology theme: deep teal + ink + paper.
// Tajawal (bundled, OFL) renders both Latin and Arabic with consistent
// shaping — no network fonts, fully offline.
// No flashy gradients, no giant red danger screens. Status is conveyed
// with label + icon + pattern-safe color (never color alone).
class OcuSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double section = 32;
}

class OcuRadii {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double pill = 24;
}

class AppTheme {
  static const ink = Color(0xFF12262B);
  static const teal = Color(0xFF0E7C7B);
  static const tealDark = Color(0xFF0A5E5D);
  static const tealTint = Color(0xFFEDF5F4);
  static const paper = Color(0xFFF7F9F8);
  static const card = Colors.white;
  static const line = Color(0xFFE2E8E6);
  static const amber = Color(0xFF9A6B00);
  static const amberTint = Color(0xFFFBF3DF);
  // A11y: slate darkened from #5B6B6B so 12px secondary text passes
  // 4.5:1 on slateTint/paper. Tints stay light; text goes dark.
  static const slate = Color(0xFF334242);
  static const slateTint = Color(0xFFEFF3F2);
  static const String fontFamily = 'Tajawal';

  static ThemeData light({bool highContrast = false, double textScale = 1.0}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
    ).copyWith(
      primary: highContrast ? Colors.black : tealDark,
      surface: paper,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: paper, foregroundColor: ink, elevation: 0,
        titleTextStyle: TextStyle(color: ink, fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      textTheme: _textTheme(textScale),
      cardTheme: const CardThemeData(
        color: card, elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tealDark, foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: tealDark,
        unselectedLabelColor: slate,
        indicatorColor: tealDark,
        labelStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontFamily: fontFamily),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: tealTint,
        iconTheme: WidgetStateProperty.resolveWith((states) =>
            IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? tealDark
                    : slate)),
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
    );
  }

  static TextTheme _textTheme(double s) {
    TextStyle t(double size, FontWeight w, {Color c = ink, double h = 1.35}) =>
        TextStyle(fontSize: size * s, fontWeight: w, color: c, height: h);
    return TextTheme(
      displaySmall: t(28, FontWeight.w800, h: 1.2),
      headlineSmall: t(22, FontWeight.w700, h: 1.25),
      titleLarge: t(19, FontWeight.w700),
      titleMedium: t(16, FontWeight.w600),
      bodyLarge: t(16, FontWeight.w400),
      bodyMedium: t(14.5, FontWeight.w400),
      bodySmall: t(13, FontWeight.w400, c: slate),
      labelLarge: t(14, FontWeight.w600),
    );
  }
}
