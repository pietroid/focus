import 'package:app_ui/src/app_icons/app_icon_data.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// {@template app_icons}
/// A collection of app icons used throughout the application.
///
/// Icons default to Phosphor; SVG assets are kept only for brand logos
/// that are not available in the Phosphor set.
/// {@endtemplate}
class AppIcons {
  /// Google Icon (SVG asset).
  static const google = AppIconData.asset('google');

  /// Pen Icon.
  static const pen = AppIconData.phosphor(PhosphorIconsRegular.pen);

  /// Home Icon.
  static const home = AppIconData.phosphor(PhosphorIconsRegular.house);

  /// Settings Icon.
  static const settings = AppIconData.phosphor(PhosphorIconsRegular.gear);

  /// Logout Icon.
  static const logout = AppIconData.phosphor(PhosphorIconsRegular.signOut);

  /// Send Icon, for submitting a prompt.
  ///
  /// The paper plane rather than an arrow in a filled circle: the sheet's
  /// send sits inside the field, where a solid disc would be the loudest
  /// thing on a black screen.
  static const send = AppIconData.phosphor(PhosphorIconsFill.paperPlaneRight);

  /// Back Icon.
  static const back = AppIconData.phosphor(PhosphorIconsRegular.arrowLeft);

  /// Check, for something that has been closed out.
  static const check = AppIconData.phosphor(PhosphorIconsBold.check);

  /// Chevron, for a row that opens something.
  static const chevronRight = AppIconData.phosphor(
    PhosphorIconsRegular.caretRight,
  );

  /// Timeline, the day as it happened and as it is still going to happen.
  static const timeline = AppIconData.phosphor(PhosphorIconsRegular.clock);

  /// Projects, the things that outlive a single day.
  static const projects = AppIconData.phosphor(PhosphorIconsRegular.folders);

  /// Recommendations, what the agent puts forward on its own.
  static const recommendations = AppIconData.phosphor(
    PhosphorIconsRegular.lightbulb,
  );

  /// Menu, everything that is not one of the three lists.
  static const menu = AppIconData.phosphor(PhosphorIconsRegular.list);

  /// Archive, for what has been put away rather than finished.
  static const archive = AppIconData.phosphor(PhosphorIconsRegular.archive);
}
