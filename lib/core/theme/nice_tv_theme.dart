import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand seed — teal-slate, not default Twitch purple unless user picks it.
const Color kNiceTvSeed = Color(0xFF1FA2A6);
const Color kTwitchPurple = Color(0xFF9146FF);
const Color kLiveBadgeRed = Color(0xFFE91916);

/// App-specific colors layered on [ColorScheme].
@immutable
class NiceTvColors extends ThemeExtension<NiceTvColors> {
  const NiceTvColors({
    required this.liveBadge,
    required this.onLiveBadge,
    required this.onMedia,
    required this.mediaScrim,
  });

  final Color liveBadge;
  final Color onLiveBadge;
  final Color onMedia;
  final Color mediaScrim;

  static const standard = NiceTvColors(
    liveBadge: kLiveBadgeRed,
    onLiveBadge: Colors.white,
    onMedia: Colors.white,
    mediaScrim: Color(0xDD000000),
  );

  static NiceTvColors of(BuildContext context) {
    return Theme.of(context).extension<NiceTvColors>() ?? standard;
  }

  @override
  NiceTvColors copyWith({
    Color? liveBadge,
    Color? onLiveBadge,
    Color? onMedia,
    Color? mediaScrim,
  }) {
    return NiceTvColors(
      liveBadge: liveBadge ?? this.liveBadge,
      onLiveBadge: onLiveBadge ?? this.onLiveBadge,
      onMedia: onMedia ?? this.onMedia,
      mediaScrim: mediaScrim ?? this.mediaScrim,
    );
  }

  @override
  NiceTvColors lerp(ThemeExtension<NiceTvColors>? other, double t) {
    if (other is! NiceTvColors) return this;
    return NiceTvColors(
      liveBadge: Color.lerp(liveBadge, other.liveBadge, t)!,
      onLiveBadge: Color.lerp(onLiveBadge, other.onLiveBadge, t)!,
      onMedia: Color.lerp(onMedia, other.onMedia, t)!,
      mediaScrim: Color.lerp(mediaScrim, other.mediaScrim, t)!,
    );
  }
}

class NiceTvTheme {
  const NiceTvTheme._();

  static ThemeData light(Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark(Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF0E1116),
    );
    return _base(scheme);
  }

  static ThemeData highContrastLight(Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      contrastLevel: 1.0,
      surface: Colors.white,
    );
    return _base(scheme);
  }

  static ThemeData highContrastDark(Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF000000),
      contrastLevel: 1.0,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final textTheme = GoogleFonts.dmSansTextTheme().apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      extensions: const <ThemeExtension<dynamic>>[NiceTvColors.standard],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
