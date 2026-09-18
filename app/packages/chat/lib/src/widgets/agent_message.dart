import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';
import 'package:chat/src/widgets/a2ui_renderer.dart';

/// {@template agent_message}
/// The agent's turn: A2UI content when available, otherwise plain text.
///
/// The alignment and skeleton are preserved from the original implementation.
/// {@endtemplate}
class AgentMessage extends StatelessWidget {
  /// {@macro agent_message}
  const AgentMessage({
    required this.message,
    required this.onAction,
    this.enabled = true,
    super.key,
  });

  /// The message to draw.
  final ChatMessage message;

  /// Called when the user interacts with an A2UI action.
  final void Function(Map<String, dynamic> action) onAction;

  /// Whether interactive components inside the message respond to taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final a2ui = message.metadata?.a2ui;

    return Align(
      alignment: Alignment.centerLeft,
      child: a2ui != null && message.isA2ui
          ? A2uiRenderer(
              component: a2ui,
              onAction: onAction,
              enabled: enabled,
            )
          : Text(
              message.text,
              style: AppTypography.bodyRegular.copyWith(color: AppColors.ink),
            ),
    );
  }
}

/// {@template agent_message_skeleton}
/// What stands in for the agent's turn while it is being written.
///
/// Shaped like the reply rather than like a spinner: same alignment, same
/// width, so nothing jumps when the text lands.
/// {@endtemplate}
class AgentMessageSkeleton extends StatelessWidget {
  /// {@macro agent_message_skeleton}
  const AgentMessageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 0.72,
        child: AppSkeletonLines(),
      ),
    );
  }
}
