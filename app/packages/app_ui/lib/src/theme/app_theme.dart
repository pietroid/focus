import 'package:app_ui/app_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// {@template app_theme}
/// Composes [ThemeData] with a dark color scheme inspired by
/// pietroid.github.io and custom [ThemeExtension]s.
///
/// Only h1 (`displayLarge`) and h2 (`displayMedium`) use Plus Jakarta Sans;
/// everything else defaults to IBM Plex Mono.
/// {@endtemplate}
class AppTheme {
  /// The dark [ThemeData].
  static ThemeData get dark {
    final baseTheme = ThemeData.dark();

    final plusJakartaSansTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      baseTheme.textTheme,
    );
    final ibmPlexMonoTextTheme = GoogleFonts.ibmPlexMonoTextTheme(
      baseTheme.textTheme,
    );

    final textTheme = ibmPlexMonoTextTheme.copyWith(
      displayLarge: plusJakartaSansTextTheme.displayLarge,
      displayMedium: plusJakartaSansTextTheme.displayMedium,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'IBM Plex Mono',
      colorScheme: const ColorScheme.dark(
        primary: Color.fromARGB(255, 55, 55, 55),
        onPrimary: Color.fromARGB(255, 231, 231, 231),
        secondary: Color(0xFF1F7A99),
        onSecondary: Color(0xFFFFFFFF),
        surface: Color(0xFF0F0F0F),
        surfaceContainerHighest: Color(0xFF1A1A1A),
        onSurfaceVariant: Color(0xFFA5A5A5),
        outline: Color(0xFF3A3A3A),
        error: Color(0xFFFF5252),
        onError: Color(0xFFFFFFFF),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      textTheme: textTheme,
      extensions: const [AppTextStyles()],
    );
  }
}
