import 'package:app_ui/app_ui.dart';

/// Visual variants for [AppButton].
enum AppButtonVariant {
  /// Accent fill. One per screen.
  primary,

  /// A neutral fill on [AppColors.fill], for secondary actions.
  secondary,

  /// No fill, for the lowest-emphasis action on a screen.
  text,
}

/// {@template app_button}
/// The app's button. Sizing, radius, and type come from the theme, so the
/// three variants differ only in colour.
/// {@endtemplate}
class AppButton extends StatelessWidget {
  /// {@macro app_button}
  const AppButton({
    required this.onPressed,
    required this.text,
    this.variant = AppButtonVariant.primary,
    this.expand = false,
    super.key,
  }) : icon = null;

  /// {@template app_button_icon}
  /// Button variant that displays an icon before the label, for sign-in
  /// providers and other actions carrying a mark.
  /// {@endtemplate}
  const AppButton.icon({
    required this.onPressed,
    required this.icon,
    required this.text,
    this.variant = AppButtonVariant.primary,
    this.expand = false,
    super.key,
  });

  /// {@template app_button_text}
  /// Button variant with no fill, for low-emphasis actions.
  /// {@endtemplate}
  const AppButton.text({
    required this.onPressed,
    required this.text,
    this.expand = false,
    super.key,
  }) : icon = null,
       variant = AppButtonVariant.text;

  /// Called when the button is tapped. A null value disables the button.
  final VoidCallback? onPressed;

  /// Optional icon displayed before the text.
  final Widget? icon;

  /// Text content displayed inside the button.
  final String text;

  /// The visual variant of the button.
  final AppButtonVariant variant;

  /// Whether the button stretches to the width of its parent.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (variant) {
      AppButtonVariant.primary => (AppColors.accent, AppColors.onAccent),
      AppButtonVariant.secondary => (AppColors.fill, AppColors.ink),
      AppButtonVariant.text => (Colors.transparent, AppColors.ink2),
    };

    final label = Text(
      text,
      style: AppTypography.body.copyWith(
        color: onPressed == null ? AppColors.ink3 : foreground,
      ),
    );

    final child = icon == null
        ? label
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(color: foreground, size: AppSpacing.s5),
                child: icon!,
              ),
              const SizedBox(width: AppSpacing.s3),
              label,
            ],
          );

    final style = FilledButton.styleFrom(
      backgroundColor: background,
      disabledBackgroundColor: variant == AppButtonVariant.primary
          ? AppColors.fillStrong
          : Colors.transparent,
      minimumSize: Size(expand ? double.infinity : 0, AppSpacing.tapTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppSpacing.buttonRadius),
        ),
      ),
    );

    return FilledButton(onPressed: onPressed, style: style, child: child);
  }
}
