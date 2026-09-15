import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';

/// {@template agent_message}
/// The agent's turn: bare content, left-aligned, no balloon.
///
/// Today that content is text. The widget exists so that when a reply becomes
/// a card or a chart, only this file changes.
/// {@endtemplate}
class AgentMessage extends StatelessWidget {
  /// {@macro agent_message}
  const AgentMessage({required this.message, super.key});

  /// The message to draw.
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
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
