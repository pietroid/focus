import 'package:app_ui/app_ui.dart';

/// {@template app_text_editor}
/// A multiline text editor that expands to fill its parent.
/// {@endtemplate}
class AppTextEditor extends StatelessWidget {
  /// {@macro app_text_editor}
  const AppTextEditor({
    this.controller,
    this.hintText,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  /// Controls the text being edited.
  final TextEditingController? controller;

  /// Text that suggests what sort of input the field accepts.
  final String? hintText;

  /// Whether the text field is interactive.
  final bool enabled;

  /// Called when the user initiates a change to the text field's value.
  final ValueChanged<String>? onChanged;

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
        keyboardType: TextInputType.multiline,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        onChanged: onChanged,
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
