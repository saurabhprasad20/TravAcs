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
      // A faint tinted background so elevated white cards visibly stand out.
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      // Coloured header. primary/onPrimary is a Material-guaranteed accessible
      // contrast pair, so this is safe without visual inspection.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      // Rounded, gently elevated cards with a subtle surface tint — more depth
      // than flat mono cards, while text keeps onSurface contrast.
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: scheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        // Larger, clearly-labeled fields aid screen-reader navigation.
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        // A bold coloured border on the focused field gives a clear, high-
        // contrast focus cue (helps low-vision users track the active field).
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      // Coloured pill behind the selected tab + a distinct bar surface, so the
      // active tab reads as "selected" by shape/colour (label is always shown
      // too, so it is never colour-only).
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
