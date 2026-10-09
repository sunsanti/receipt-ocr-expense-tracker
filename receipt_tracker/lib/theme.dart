import 'package:flutter/material.dart';

// Design tokens — see design-system/receipt-tracker/MASTER.md.
// Style: Minimalism/Swiss + flat. Palette: "Personal Finance Tracker"
// (trust blue, success green, alert red). Type: Lexend (headings, numbers)
// + Source Sans 3 (body), bundled so the app stays fully offline.

/// 4/8dp spacing rhythm.
abstract final class Space {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
}

/// Motion tokens. Charts and overlays use [Motion.of] so reduced-motion
/// settings turn animations off.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const chart = Duration(milliseconds: 700);
  static Duration of(BuildContext context, Duration d) => MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

const maxContentWidth = 640.0;

/// Category identity: color + icon, so color is never the only cue.
const categoryColors = {
  'Food': Color(0xFFEA580C),
  'Study': Color(0xFF7C3AED),
  'Travel': Color(0xFF0891B2),
  'Gear': Color(0xFF65A30D),
  'Entertainment': Color(0xFFDB2777),
};
const categoryIcons = {
  'Food': Icons.restaurant_outlined,
  'Study': Icons.school_outlined,
  'Travel': Icons.commute_outlined,
  'Gear': Icons.devices_other_outlined,
  'Entertainment': Icons.local_activity_outlined,
};

/// Category color, lifted in dark mode to keep ≥3:1 against dark surfaces.
Color categoryColor(BuildContext context, String category) {
  final c = categoryColors[category] ?? const Color(0xFF64748B);
  return Theme.of(context).brightness == Brightness.dark ? Color.lerp(c, Colors.white, .35)! : c;
}

/// Variable fonts: set the `wght` axis explicitly alongside [FontWeight].
TextStyle weight(TextStyle s, int w) =>
    s.copyWith(fontWeight: FontWeight.values[(w ~/ 100 - 1).clamp(0, 8)], fontVariations: [FontVariation.weight(w.toDouble())]);

/// Tabular figures so amounts line up in lists.
const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: Color(0xFF60A5FA),
          onPrimary: Color(0xFF0F172A),
          primaryContainer: Color(0xFF1E3A8A),
          onPrimaryContainer: Color(0xFFDBEAFE),
          secondary: Color(0xFF93C5FD),
          onSecondary: Color(0xFF0F172A),
          secondaryContainer: Color(0xFF24304A),
          onSecondaryContainer: Color(0xFFDBEAFE),
          tertiary: Color(0xFF34D399),
          onTertiary: Color(0xFF052E1C),
          error: Color(0xFFF87171),
          onError: Color(0xFF0F172A),
          surface: Color(0xFF0F172A),
          onSurface: Color(0xFFF8FAFC),
          onSurfaceVariant: Color(0xFF94A3B8),
          surfaceContainerLowest: Color(0xFF192134),
          surfaceContainerLow: Color(0xFF1C2539),
          surfaceContainer: Color(0xFF1F2940),
          surfaceContainerHigh: Color(0xFF24304A),
          surfaceContainerHighest: Color(0xFF2B3854),
          outline: Color(0xFF475569),
          outlineVariant: Color(0xFF334155),
        )
      : const ColorScheme.light(
          primary: Color(0xFF1E40AF),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFDBEAFE),
          onPrimaryContainer: Color(0xFF1E3A8A),
          secondary: Color(0xFF3B82F6),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFEFF6FF),
          onSecondaryContainer: Color(0xFF1E3A8A),
          tertiary: Color(0xFF059669),
          onTertiary: Colors.white,
          error: Color(0xFFDC2626),
          onError: Colors.white,
          surface: Color(0xFFF8FAFC),
          onSurface: Color(0xFF0F172A),
          onSurfaceVariant: Color(0xFF475569),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Color(0xFFF1F5F9),
          surfaceContainer: Color(0xFFEEF2F7),
          surfaceContainerHigh: Color(0xFFE2E8F0),
          surfaceContainerHighest: Color(0xFFCBD5E1),
          outline: Color(0xFF94A3B8),
          outlineVariant: Color(0xFFE2E8F0),
        );

  final base = Typography.material2021(platform: TargetPlatform.android).black.apply(
        fontFamily: 'SourceSans3',
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );
  TextStyle head(TextStyle? s, int w) => weight(s!.copyWith(fontFamily: 'Lexend', letterSpacing: -0.2), w);
  final text = base.copyWith(
    displaySmall: head(base.displaySmall, 600),
    headlineLarge: head(base.headlineLarge, 600),
    headlineMedium: head(base.headlineMedium, 600),
    headlineSmall: head(base.headlineSmall, 600),
    titleLarge: head(base.titleLarge, 600),
    titleMedium: head(base.titleMedium, 600),
    titleSmall: head(base.titleSmall, 600),
    bodyLarge: weight(base.bodyLarge!.copyWith(fontSize: 16, height: 1.5), 400),
    bodyMedium: weight(base.bodyMedium!.copyWith(fontSize: 15, height: 1.45), 400),
    bodySmall: weight(base.bodySmall!.copyWith(fontSize: 13, color: scheme.onSurfaceVariant), 400),
    labelLarge: weight(base.labelLarge!.copyWith(fontSize: 15), 600),
    labelMedium: weight(base.labelMedium!.copyWith(fontSize: 13), 600),
    labelSmall: weight(base.labelSmall!.copyWith(fontSize: 12), 600),
  );

  final radius12 = BorderRadius.circular(12);
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge!.copyWith(fontSize: 22),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide(color: scheme.outline)),
      enabledBorder: OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide(color: scheme.outline)),
      focusedBorder: OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide(color: scheme.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.lg),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: radius12),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: radius12),
        textStyle: text.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      extendedTextStyle: text.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outline),
      labelStyle: text.labelLarge!.copyWith(color: scheme.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius12),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
      minVerticalPadding: Space.md,
      titleTextStyle: weight(text.bodyLarge!, 600),
      subtitleTextStyle: text.bodySmall,
    ),
    expansionTileTheme: const ExpansionTileThemeData(shape: Border(), collapsedShape: Border()),
  );
}

/// Centers content and caps its width on tablets / large screens.
class ContentWidth extends StatelessWidget {
  final Widget child;
  const ContentWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Center(
        heightFactor: 1, // only as tall as the child, so it also works in bottom bars
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: maxContentWidth), child: child),
      );
}

/// Rounded square with a category icon, tinted with its color.
class CategoryBadge extends StatelessWidget {
  final String category;
  final double size;
  const CategoryBadge(this.category, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = categoryColor(context, category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: .14), borderRadius: BorderRadius.circular(size / 3.2)),
      child: Icon(categoryIcons[category] ?? Icons.category_outlined, color: c, size: size * .5),
    );
  }
}
