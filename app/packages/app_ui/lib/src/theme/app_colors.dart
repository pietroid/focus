import 'package:flutter/material.dart';

/// {@template app_colors}
/// Static color tokens used throughout the app.
/// {@endtemplate}
class AppColors {
  AppColors._();

  /// Background color used by text fields and editors.
  static const Color textFieldBackground = Color(0xFF1F1F1F);

  /// Color used by the cursor in text fields.
  static const Color cursorColor = Color(0xFFFFFFFF);

  /// Primary accent color (lime).
  static const Color primary = Color(0xFFE6FF0D);

  /// Color rendered on top of the primary color.
  static const Color onPrimary = Color(0xFF0F0F0F);

  /// Secondary accent color (teal).
  static const Color secondary = Color(0xFF1F7A99);

  /// Main background color.
  static const Color background = Color(0xFF0F0F0F);

  /// Surface color for cards and elevated containers.
  static const Color surface = Color(0xFF1A1A1A);

  /// Muted/on-surface-variant color for secondary text.
  static const Color muted = Color(0xFFA5A5A5);

  /// Outline / divider color.
  static const Color outline = Color(0xFF3A3A3A);

  /// Error color.
  static const Color error = Color(0xFFFF5252);
}
