import 'package:app_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The type tokens for Focus.
///
/// One face, Onest, across the whole app. Weight and size carry the hierarchy
/// instead of a second family, and tracking tightens as the size grows so a
/// 96pt clock and a 12pt caption sit on the same optical rhythm.
abstract final class AppTypography {
  /// Onest, the only face. Every style in the app resolves through here.
  static TextStyle onest({
    required double size,
    required FontWeight weight,
    double height = 1.3,
    double tracking = -0.01,
    Color color = AppColors.ink,
  }) {
    return GoogleFonts.onest(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: size * tracking,
      color: color,
    );
  }

  /// 88/200. The clock. The one piece of type the home screen is built around.
  static TextStyle get clock => onest(
    size: 88,
    weight: FontWeight.w200,
    height: 1,
    tracking: -0.025,
  );

  /// 40/300. Billboard headings.
  static TextStyle get display =>
      onest(size: 40, weight: FontWeight.w300, height: 1.1, tracking: -0.02);

  /// 28/400. Screen headings.
  static TextStyle get headline =>
      onest(size: 28, weight: FontWeight.w400, height: 1.15, tracking: -0.02);

  /// 20/500. Section headers.
  static TextStyle get title =>
      onest(size: 20, weight: FontWeight.w500, height: 1.2);

  /// 16/500. Item titles and button labels.
  static TextStyle get body =>
      onest(size: 16, weight: FontWeight.w500, height: 1.25);

  /// 16/400. Running text and input values.
  static TextStyle get bodyRegular =>
      onest(size: 16, weight: FontWeight.w400, height: 1.45);

  /// 14/400. Labels, subtitles, and the prompt caption.
  static TextStyle get label =>
      onest(size: 14, weight: FontWeight.w400, color: AppColors.ink2);

  /// 14/500. Chip and control labels.
  static TextStyle get labelStrong => onest(size: 14, weight: FontWeight.w500);

  /// 12/500. Captions and tab labels.
  static TextStyle get caption => onest(
    size: 12,
    weight: FontWeight.w500,
    color: AppColors.ink2,
  );

  /// The Material text theme, built from the scale above.
  static TextTheme get textTheme => TextTheme(
    displayLarge: onest(
      size: 57,
      weight: FontWeight.w200,
      height: 1.05,
      tracking: -0.025,
    ),
    displayMedium: onest(
      size: 48,
      weight: FontWeight.w200,
      height: 1.08,
      tracking: -0.025,
    ),
    displaySmall: display,
    headlineLarge: headline,
    headlineMedium: onest(
      size: 24,
      weight: FontWeight.w400,
      height: 1.2,
      tracking: -0.02,
    ),
    headlineSmall: title,
    titleLarge: title,
    titleMedium: body,
    titleSmall: labelStrong,
    bodyLarge: bodyRegular,
    bodyMedium: label,
    bodySmall: caption,
    labelLarge: body,
    labelMedium: labelStrong,
    labelSmall: caption,
  );
}
