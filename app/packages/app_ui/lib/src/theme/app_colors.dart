import 'package:flutter/material.dart';

/// The color tokens for Focus.
///
/// Focus is a dark-only app built on true black, so the screen disappears and
/// only the content is lit. Surfaces are opaque greys rather than translucent
/// whites: on black a translucent white lifts the hue of whatever sits behind
/// it, and the app leans on a single neutral ramp.
abstract final class AppColors {
  /// The page background behind every screen. True black.
  static const bg = Color(0xFF000000);

  /// The surface a sheet, a menu, or a dialog sits on.
  static const surface = Color(0xFF0D0D0D);

  /// The borderless fill that gives a field or a card its shape.
  static const fill = Color(0xFF1C1C1C);

  /// A heavier [fill], for pressed states, tracks, and inactive bars.
  static const fillStrong = Color(0xFF2B2B2B);

  /// Hairline separators.
  static const line = Color(0xFF232323);

  /// Text primary: the lit content.
  static const ink = Color(0xFFF5F5F5);

  /// Text secondary: labels, captions, and subtitles.
  static const ink2 = Color(0xFFA1A1A1);

  /// Text tertiary: placeholders and disabled content.
  static const ink3 = Color(0xFF6B6B6B);

  /// The accent. The single colour the whole app hangs off.
  static const accent = Color(0xFFE6FF0D);

  /// Content drawn on top of [accent].
  static const onAccent = Color(0xFF000000);

  /// A 14% accent tint, for accent-washed fills.
  static const accentSoft = Color(0x24E6FF0D);

  /// Positive / success.
  static const positive = Color(0xFF3ECF8E);

  /// Negative / error.
  static const negative = Color(0xFFFF5A5A);
}
