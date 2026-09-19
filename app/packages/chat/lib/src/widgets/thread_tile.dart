import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';

/// {@template thread_tile}
/// One thread on the home screen's list.
///
/// The title and nothing else. Which list a card is in already says when it
/// happens, so a timestamp next to it would be a second, quieter answer to
/// the same question.
///
/// It carries no gestures of its own. Tapping and dragging on the home screen
/// are read by one listener over the whole list, which tells each card how it
/// is being touched through [pressed], [hidden], and [lifted].
/// {@endtemplate}
class ThreadTile extends StatelessWidget {
  /// {@macro thread_tile}
  const ThreadTile({
    required this.thread,
    this.pressed = false,
    this.hidden = false,
    this.lifted = false,
    super.key,
  });

  /// The thread to draw.
  final ThreadSummary thread;

  /// Whether a finger is resting on it.
  final bool pressed;

  /// Whether this is the place a card in the air left open behind it.
  ///
  /// It is still laid out, and still the full size it was, so the lists it
  /// left keep the shape they had while it is gone.
  final bool hidden;

  /// Whether this is the copy that follows the finger.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: hidden ? 0 : 1,
      child: Material(
        color: pressed || lifted ? AppColors.fillStrong : AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        elevation: lifted ? 8 : 0,
        shadowColor: AppColors.bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          child: Text(
            thread.title,
            style: AppTypography.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
