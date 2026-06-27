import 'package:flutter/material.dart';

/// Accessible theme for TravAcs (design §11): high-contrast color scheme,
/// scalable text (no fixed font sizes that break with OS large-text), and
/// large touch targets (>=48dp). Material 3.
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF0B5FFF); // strong, high-contrast blue

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Ensure minimum 48dp tap targets everywhere for motor + screen-reader use.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        // Larger, clearly-labeled fields aid screen-reader navigation.
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
      ),
    );
  }
}
