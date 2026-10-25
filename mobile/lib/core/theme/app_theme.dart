import 'package:flutter/material.dart';

/// CivicAI Design System — App Theme
///
/// Palette: Navy/Blue primary, Teal accent, warm neutrals
/// Typography: System default (add Inter from Google Fonts in Phase 3 or
///   place Inter .ttf files in assets/fonts/ and uncomment pubspec.yaml fonts)
class AppTheme {
  AppTheme._();

  // ── Brand colors ──────────────────────────────────────────────────────────
  static const Color primaryNavy = Color(0xFF1A3A5C);
  static const Color primaryNavyLight = Color(0xFF2D5986);
  static const Color tealAccent = Color(0xFF0D9488);
  static const Color tealAccentLight = Color(0xFF5EEAD4);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color infoBlue = Color(0xFF0284C7);

  // ── Status colors ─────────────────────────────────────────────────────────
  static const Color statusPending = Color(0xFFD97706);
  static const Color statusInProgress = Color(0xFF0284C7);
  static const Color statusEscalated = Color(0xFFDC2626);
  static const Color statusResolved = Color(0xFF16A34A);
  static const Color statusClosed = Color(0xFF6B7280);
  static const Color statusRejected = Color(0xFF7C3AED);

  // ── Neutral shades ────────────────────────────────────────────────────────
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceGray50 = Color(0xFFF9FAFB);
  static const Color surfaceGray100 = Color(0xFFF3F4F6);
  static const Color borderGray200 = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Spacing scale ─────────────────────────────────────────────────────────
  static const double sp4 = 4.0;
  static const double sp8 = 8.0;
  static const double sp12 = 12.0;
  static const double sp14 = 14.0;
  static const double sp16 = 16.0;
  static const double sp20 = 20.0;
  static const double sp24 = 24.0;
  static const double sp32 = 32.0;
  static const double sp48 = 48.0;
  static const double sp64 = 64.0;

  // ── Border radii ──────────────────────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  // ── Elevation / Shadows ───────────────────────────────────────────────────
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // ── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        primary: primaryNavy,
        secondary: tealAccent,
        error: errorRed,
        surface: surfaceWhite,
        onPrimary: textOnPrimary,
        onSecondary: textOnPrimary,
        onError: textOnPrimary,
        onSurface: textPrimary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: surfaceGray50,
      // fontFamily: 'Inter', // Uncomment after adding font files to assets/fonts/
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderGray200, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: textOnPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryNavy,
          side: const BorderSide(color: primaryNavy, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tealAccent,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: sp16,
          vertical: sp14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderGray200, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderGray200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryNavy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: textTertiary,
          fontSize: 14,
        ),
        errorStyle: const TextStyle(
          color: errorRed,
          fontSize: 12,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        selectedItemColor: primaryNavy,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderGray200,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceGray100,
        selectedColor: primaryNavy.withValues(alpha: 0.12),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        padding: const EdgeInsets.symmetric(horizontal: sp8, vertical: sp4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: tealAccent,
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -1.0,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.8,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.3,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.2,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
        fontSize: 18,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
        fontSize: 16,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
        fontSize: 14,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        color: textPrimary,
        fontSize: 16,
        height: 1.6,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        color: textPrimary,
        fontSize: 14,
        height: 1.5,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        color: textSecondary,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 0.4,
      ),
    );
  }

  // ── Status helpers ────────────────────────────────────────────────────────
  static Color statusColor(String status) => switch (status.toLowerCase()) {
        'pending' => statusPending,
        'in_progress' || 'assigned' => statusInProgress,
        'escalated' => statusEscalated,
        'resolved' => statusResolved,
        'closed' => statusClosed,
        'rejected' => statusRejected,
        _ => textSecondary,
      };

  static Color statusBgColor(String status) =>
      statusColor(status).withValues(alpha: 0.12);

  static String statusLabel(String status) => switch (status.toLowerCase()) {
        'pending' => 'Pending',
        'in_progress' => 'In Progress',
        'assigned' => 'Assigned',
        'escalated' => 'Escalated',
        'resolved' => 'Resolved',
        'closed' => 'Closed',
        'rejected' => 'Rejected',
        _ => status,
      };
}
