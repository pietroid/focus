import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';

/// {@template event_tile}
/// One card on the timeline: a block of time.
///
/// The title and the hour. Every card has an hour now, so the line beside the
/// title is always the same thing and never has to stand in for a missing
/// one. A fixed card says so with a pin: it is the one card on the screen
/// that will not move when the day is rearranged, and that is worth knowing
/// before rearranging it.
///
/// A meeting Focus did not book looks the same and behaves differently: it
/// carries a small mark saying where it came from, and the list above ignores
/// every gesture on it.
///
/// It carries no gestures of its own. Tapping and dragging on the timeline
/// are read by one listener over the whole list, which tells each card how it
/// is being touched through [pressed], [hidden], and [lifted].
/// {@endtemplate}
class EventTile extends StatelessWidget {
  /// {@macro event_tile}
  const EventTile({
    required this.card,
    this.pressed = false,
    this.hidden = false,
    this.lifted = false,
    super.key,
  });

  /// The card to draw.
  final TimelineEvent card;

  /// Whether a finger is resting on it.
  final bool pressed;

  /// Whether this is the place a card in the air left open behind it.
  ///
  /// It is still laid out, and still the full size it was, so the list it
  /// left keeps the shape it had while it is gone.
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
          child: Row(
            children: [
              // The mark comes before the title, where it reads as "this one
              // is Google's" or "this one is pinned", rather than after it,
              // where it would read as a status the thread had earned.
              if (_mark != null) ...[
                AppIcon(
                  iconData: _mark!,
                  size: AppSpacing.s4,
                  color: AppColors.ink3,
                ),
                const SizedBox(width: AppSpacing.s2),
              ],
              Expanded(
                child: Text(
                  card.title,
                  style: AppTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                '${_hhmm(card.startTime)}-${_hhmm(card.endTime)}',
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The small icon in front of the title, when the card has earned one.
  AppIconData? get _mark {
    if (!card.managed) return AppIcons.calendar;
    return card.fixed ? AppIcons.pin : null;
  }

  static String _hhmm(DateTime at) {
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }
}
