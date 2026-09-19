import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// {@template app_prompt_sheet}
/// The sheet the orb opens: one field, one send, nothing else.
///
/// It is the only place in the app where the user starts something, so it is
/// deliberately bare: black, a line of text on it, and no box drawn around
/// anything. The hint is picked at random from [hints] each time the sheet
/// opens, which is the whole of its personality.
/// {@endtemplate}
class AppPromptSheet extends StatefulWidget {
  /// {@macro app_prompt_sheet}
  const AppPromptSheet({super.key});

  /// The ways the sheet asks what the user wants.
  ///
  /// All ten mean the same thing. They exist so that opening the sheet twice
  /// in a row does not feel like opening the same drawer twice.
  static const hints = <String>[
    'O que posso ajudar?',
    'Em que posso ajudar?',
    'No que vamos trabalhar?',
    'O que você precisa agora?',
    'Por onde começamos?',
    'O que está na sua cabeça?',
    'Me conta o que precisa.',
    'Qual é a próxima?',
    'O que resolvemos hoje?',
    'Pode falar.',
  ];

  /// Opens the sheet and resolves with the trimmed text, or null if it was
  /// dismissed without sending.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bg.withValues(alpha: 0.72),
      builder: (_) => const AppPromptSheet(),
    );
  }

  @override
  State<AppPromptSheet> createState() => _AppPromptSheetState();
}

class _AppPromptSheetState extends State<AppPromptSheet> {
  final _controller = TextEditingController();
  late final String _hint =
      AppPromptSheet.hints[math.Random().nextInt(AppPromptSheet.hints.length)];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The sheet sits on the keyboard rather than under it, so the field is
      // still visible the moment it takes focus.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ColoredBox(
        color: AppColors.bg,
        child: SafeArea(
          top: false,
          // The sheet is the width of the screen, not of a reading column:
          // it is one line of input and a send, and a 560pt box centred in a
          // wider window would sit off the orb that opened it.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s5,
              AppSpacing.s2,
              AppSpacing.s3,
              AppSpacing.s2,
            ),
            child: _Field(
              controller: _controller,
              hint: _hint,
              onSubmit: _submit,
            ),
          ),
        ),
      ),
    );
  }
}

/// The field: no fill, no border, the send sitting beside it.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSubmit(),
                cursorColor: AppColors.ink,
                cursorWidth: 1.5,
                cursorRadius: const Radius.circular(AppSpacing.s1),
                style: AppTypography.body,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.ink3,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s4,
                  ),
                ),
              ),
            ),
            _Send(
              enabled: value.text.trim().isNotEmpty,
              onPressed: onSubmit,
            ),
          ],
        );
      },
    );
  }
}

/// The send: a bare icon that lights up once there is something to send.
class _Send extends StatelessWidget {
  const _Send({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.tapTarget,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.35,
              duration: const Duration(milliseconds: 160),
              child: const AppIcon(
                iconData: AppIcons.send,
                size: AppSpacing.s5,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
