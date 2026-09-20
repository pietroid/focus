import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';

/// {@template thread_tile}
/// One card on the home screen's timeline.
///
/// The title, and the time when there is one. Which list a card is in says
/// roughly when it happens, so the line beside the title is only ever the
/// part the list cannot say: the hour it starts, or how long it takes when
/// nobody has picked an hour yet.
///
/// A card read off the calendar looks the same and behaves differently: it
/// carries a small mark saying where it came from, and the list above ignores
/// every gesture on it.
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

  /// The card to draw.
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
    final detail = _detail(thread);

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
          child: Row(
            children: [
              // The calendar mark comes before the title, where it reads as
              // "this one is Google's", rather than after it, where it would
              // read as a status the thread had earned.
              if (thread.kind == CardKind.calendar) ...[
                const AppIcon(
                  iconData: AppIcons.calendar,
                  size: AppSpacing.s4,
                  color: AppColors.ink3,
                ),
                const SizedBox(width: AppSpacing.s2),
              ],
              Expanded(
                child: Text(
                  thread.title,
                  style: AppTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(width: AppSpacing.s3),
                Text(
                  detail,
                  style: AppTypography.label.copyWith(color: AppColors.ink3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The line beside the title: the hour, or the length, or nothing.
  ///
  /// A card with a time says the time. One that only knows how long it takes
  /// says that instead, because it is the whole of what the user told the
  /// guard and it is what the next guard will start from.
  static String? _detail(ThreadSummary thread) {
    final start = thread.startTime;
    final end = thread.endTime;

    if (start != null && end != null) {
      return '${_hhmm(start)}-${_hhmm(end)}';
    }

    final minutes = thread.durationMinutes;
    return minutes == null ? null : _length(minutes);
  }

  static String _hhmm(DateTime at) {
    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  /// "45 min", "1 h", "1h30", written exactly as the guard's buttons write it.
  static String _length(int minutes) {
    if (minutes < 60) return '$minutes min';

    final hours = minutes ~/ 60;
    final rest = minutes % 60;

    if (rest == 0) return '$hours h';

    return '${hours}h${rest.toString().padLeft(2, '0')}';
  }
}
