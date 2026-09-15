import 'package:app_ui/app_ui.dart';

/// {@template app_prompt_field}
/// The home screen's prompt: a caption over a pill field.
///
/// The caption is part of the control rather than a loose [Text] above it, so
/// the gap between the two is a token and not a decision a screen re-makes.
/// {@endtemplate}
class AppPromptField extends StatelessWidget {
  /// {@macro app_prompt_field}
  const AppPromptField({
    required this.caption,
    this.controller,
    this.focusNode,
    this.hintText,
    this.onSubmitted,
    super.key,
  });

  /// The line shown above the field.
  final String caption;

  /// Controls the text being edited.
  final TextEditingController? controller;

  /// Controls the focus of the field.
  final FocusNode? focusNode;

  /// Text that suggests what sort of input the field accepts.
  final String? hintText;

  /// Called when the user submits the prompt.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(caption, style: AppTypography.label, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s4),
        AppTextField(
          controller: controller,
          focusNode: focusNode,
          hintText: hintText,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.send,
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }
}
