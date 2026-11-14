import 'package:flutter/material.dart';

/// CivicAI design tokens — shared with the web console.
///
/// Deep teal primary, warm amber accent, near-black ink and a warm
/// off-white canvas. Radii and spacing follow the console's 4pt scale.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF0E7C66);
  static const primaryDark = Color(0xFF0B5F4F);
  static const primaryDeep = Color(0xFF0B1714);
  static const primarySoft = Color(0xFFE7F3EF);

  static const amber = Color(0xFFF5B942);
  static const amberDeep = Color(0xFF8A5A0B);
  static const amberSoft = Color(0xFFFDF3DB);

  static const ink = Color(0xFF0B1714);
  static const ink2 = Color(0xFF3C4A45);
  static const ink3 = Color(0xFF6B7A74);

  static const canvas = Color(0xFFF6F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3E7E2);

  static const danger = Color(0xFFC2413B);
  static const dangerSoft = Color(0xFFFBEAE8);
  static const warn = Color(0xFFB7791F);
  static const warnSoft = Color(0xFFFDF3DB);
  static const info = Color(0xFF2A6F9B);
  static const infoSoft = Color(0xFFE8F1F7);
  static const success = Color(0xFF0E7C66);
  static const successSoft = Color(0xFFE7F3EF);
}

class AppRadii {
  AppRadii._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
  static const pill = 999.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.amber,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.amberSoft,
      onSecondaryContainer: AppColors.amberDeep,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerSoft,
      onErrorContainer: AppColors.danger,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.ink3,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
      shadow: Color(0x140B1714),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: null,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.ink,
            displayColor: AppColors.ink,
          )
          .copyWith(
            headlineSmall: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: AppColors.ink,
            ),
            titleLarge: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: AppColors.ink,
            ),
            titleMedium: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.ink2,
            ),
            bodySmall: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.ink3,
            ),
            labelSmall: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.ink3,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.ink3, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.ink2, fontSize: 13.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.line),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySoft,
        side: const BorderSide(color: AppColors.line),
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.ink2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.ink3,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11.5),
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryDeep,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.line,
        ),
      ),
    );
  }
}
