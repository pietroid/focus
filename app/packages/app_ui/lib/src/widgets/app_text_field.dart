import 'package:app_ui/app_ui.dart';

/// {@template app_text_field}
/// A styled text field with a gray background and rounded corners.
/// {@endtemplate}
class AppTextField extends StatelessWidget {
  /// {@macro app_text_field}
  const AppTextField({
    this.controller,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  /// Controls the text being edited.
  final TextEditingController? controller;

  /// Text that suggests what sort of input the field accepts.
  final String? hintText;

  /// The type of keyboard to use for editing the text.
  final TextInputType? keyboardType;

  /// Whether to hide the text being edited (e.g., for passwords).
  final bool obscureText;

  /// Whether the text field is interactive.
  final bool enabled;

  /// Called when the user initiates a change to the text field's value.
  final ValueChanged<String>? onChanged;

  /// Called when the user indicates that they are done editing the text.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    const backgroundColor = AppColors.textFieldBackground;
    const cursorColor = AppColors.cursorColor;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: backgroundColor,
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        cursorColor: cursorColor,
        cursorWidth: 1,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
