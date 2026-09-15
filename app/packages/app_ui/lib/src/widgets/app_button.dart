import 'package:app_ui/app_ui.dart';

/// Visual variants for [AppButton].
enum AppButtonVariant {
  /// A filled button with the primary color.
  primary,

  /// A tonal filled button with a secondary color.
  secondary,

  /// Text Button.
  text,
}

enum _AppButtonType { filled, icon, text }

/// {@template app_button}
/// A styled button that composes Material's [FilledButton] and
/// [OutlinedButton] with app-specific sizing and theming.
/// {@endtemplate}
class AppButton extends StatelessWidget {
  /// {@macro app_button}
  const AppButton({
    required this.onPressed,
    required this.text,
    this.variant = AppButtonVariant.primary,
    super.key,
  }) : icon = null,
       _type = _AppButtonType.filled;

  /// {@template app_button_icon}
  /// Button variant that displays an icon before the label.
  ///
  /// Useful for sign-in providers such as Google or Apple.
  /// {@endtemplate}
  const AppButton.icon({
    required this.onPressed,
    required this.icon,
    required this.text,
    this.variant = AppButtonVariant.primary,
    super.key,
  }) : _type = _AppButtonType.icon;

  /// {@template app_button_text}
  /// Button variant that displays only text without a background.
  ///
  /// Useful for low emphasis actions such as bottom bars.
  /// {@endtemplate}
  const AppButton.text({
    required this.onPressed,
    required this.text,
    this.variant = AppButtonVariant.primary,
    super.key,
  }) : icon = null,
       _type = _AppButtonType.text;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// Optional icon displayed before the text.
  final Widget? icon;

  /// Text content displayed inside the button.
  final String text;

  /// The visual variant of the button.
  final AppButtonVariant variant;

  final _AppButtonType _type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTextVariant = _type == _AppButtonType.text;
    final foregroundColor = switch (variant) {
      AppButtonVariant.primary => colorScheme.onPrimary,
      AppButtonVariant.secondary => colorScheme.onSurface,
      AppButtonVariant.text => colorScheme.onSurface,
    };
    final backgroundColor = switch (variant) {
      AppButtonVariant.primary => colorScheme.primary,
      AppButtonVariant.secondary => colorScheme.surface,
      AppButtonVariant.text => null,
    };
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: variant == AppButtonVariant.text
          ? FontWeight.w700
          : FontWeight.w500,
      color: foregroundColor,
    );
    final label = Text(text, style: textStyle);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: isTextVariant ? Alignment.center : null,
        decoration: isTextVariant
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: backgroundColor,
                border: variant == AppButtonVariant.secondary
                    ? Border.all(color: colorScheme.outline)
                    : null,
              ),
        child: icon == null
            ? label
            : _AppButtonIconContent(
                icon: icon!,
                label: label,
                iconColor: foregroundColor,
              ),
      ),
    );
  }
}

class _AppButtonIconContent extends StatelessWidget {
  const _AppButtonIconContent({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final Widget icon;
  final Widget label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTheme(
          data: IconTheme.of(context).copyWith(color: iconColor),
          child: icon,
        ),
        const SizedBox(width: 12),
        label,
      ],
    );
  }
}
