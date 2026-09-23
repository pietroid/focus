import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';
import 'package:chat/src/widgets/now_surface.dart';

/// {@template event_tile}
/// One card on the timeline: a block of time.
///
/// The title and the hour it starts. Only the start: the next card says when
/// this one ends, near enough, and two times per line made the day read like
/// a timetable. A fixed card says so with a pin: it is the one card on the
/// screen that will not move when the day is rearranged, and that is worth
/// knowing before rearranging it. A routine's day carries a repeat mark and a
/// faintly different fill, so lunch reads as lunch before its title does.
///
/// A flexible block whose hour has come waits for the user, and says so in
/// place of the progress bar: begin it, or give it fifteen minutes more.
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
    this.actionsKey,
    this.onPauseToggled,
    this.onAdjusted,
    this.onDone,
    this.onStarted,
    this.onSnoozed,
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

  /// Put on the row of buttons, so the list's own gesture can leave a tap on
  /// one of them alone.
  final Key? actionsKey;

  /// Pauses or resumes. The buttons are only drawn when this is given.
  final VoidCallback? onPauseToggled;

  /// Asks for fifteen minutes more, or fewer when negative.
  final ValueChanged<int>? onAdjusted;

  /// Marks it done.
  final VoidCallback? onDone;

  /// Begins a block that is waiting to be begun.
  final VoidCallback? onStarted;

  /// Gives a waiting block fifteen minutes more.
  final VoidCallback? onSnoozed;

  /// Whether this is the block being lived through.
  bool get _isNow => card.section == TimelineSection.agora;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                  style: AppTypography.body.copyWith(
                    color: card.isPaused ? AppColors.ink2 : AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                _hhmm(card.startTime),
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
          if (_isNow && card.awaitingStart) ...[
            const SizedBox(height: AppSpacing.s2),
            _StartPrompt(
              key: actionsKey,
              onStarted: onStarted,
              onSnoozed: onSnoozed,
            ),
          ] else if (_isNow) ...[
            const SizedBox(height: AppSpacing.s2),
            NowProgress(card: card, trailing: _actions()),
          ],
        ],
      ),
    );

    return Opacity(
      opacity: hidden ? 0 : 1,
      child: Material(
        type: _isNow ? MaterialType.transparency : MaterialType.canvas,
        color: _isNow
            ? null
            : pressed || lifted
            ? AppColors.fillStrong
            : card.isRoutine
            ? AppColors.routineFill
            : AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        elevation: lifted ? 8 : 0,
        shadowColor: AppColors.bg,
        child: _isNow
            ? NowSurface(
                // Waiting is quiet, like a pause: nothing is running yet.
                paused: card.isPaused || card.awaitingStart,
                pressed: pressed || lifted,
                child: body,
              )
            : body,
      ),
    );
  }

  /// Pause, fifteen minutes either way, and done, when there is anyone to
  /// tell.
  Widget? _actions() {
    if (!card.isInteractive || onPauseToggled == null) return null;

    return EventControls(
      key: actionsKey,
      card: card,
      onPauseToggled: onPauseToggled,
      onAdjusted: onAdjusted!,
      onDone: onDone!,
    );
  }

  /// The small icon in front of the title, when the card has earned one.
  AppIconData? get _mark {
    if (!card.managed) return AppIcons.calendar;
    if (card.isRoutine) return AppIcons.repeat;
    return card.fixed ? AppIcons.pin : null;
  }

  static String _hhmm(DateTime at) {
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }
}

/// {@template event_controls}
/// The quiet row of buttons a block is worked with.
///
/// Pause or resume while it runs, start it now when it has not started,
/// fifteen minutes either way, and done. The running card on the timeline and
/// the block's own screen draw the same row, so a button means the same thing
/// in both places.
/// {@endtemplate}
class EventControls extends StatelessWidget {
  /// {@macro event_controls}
  const EventControls({
    required this.card,
    required this.onAdjusted,
    required this.onDone,
    this.onPauseToggled,
    this.onStarted,
    super.key,
  });

  /// The block.
  final TimelineEvent card;

  /// Pauses or resumes. Only drawn while it runs.
  final VoidCallback? onPauseToggled;

  /// Starts it now. Only drawn before it has started.
  final VoidCallback? onStarted;

  /// Asks for fifteen minutes more, or fewer when negative.
  final ValueChanged<int> onAdjusted;

  /// Marks it done.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final running = card.isRunningAt(now);
    final shortens = card.canShorten(15, now);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A block waiting to be begun is running on the clock and not in
        // fact, so its button begins it rather than pausing it.
        if (card.awaitingStart && onStarted != null)
          _Action(
            tooltip: 'Começar',
            onTap: onStarted,
            child: const AppIcon(
              iconData: AppIcons.play,
              size: AppSpacing.s4,
              color: AppColors.ink,
            ),
          )
        else if (running && onPauseToggled != null)
          _Action(
            tooltip: card.isPaused ? 'Retomar' : 'Pausar',
            onTap: onPauseToggled,
            child: AppIcon(
              iconData: card.isPaused ? AppIcons.play : AppIcons.pause,
              size: AppSpacing.s4,
              color: card.isPaused ? AppColors.ink : AppColors.ink2,
            ),
          )
        else if (!running && onStarted != null)
          _Action(
            tooltip: 'Começar agora',
            onTap: onStarted,
            child: const AppIcon(
              iconData: AppIcons.play,
              size: AppSpacing.s4,
              color: AppColors.ink2,
            ),
          ),
        _Action(
          tooltip: 'Menos 15 min',
          onTap: shortens ? () => onAdjusted(-15) : null,
          child: Text(
            '−15',
            style: AppTypography.labelStrong.copyWith(
              color: shortens ? AppColors.ink2 : AppColors.ink3,
            ),
          ),
        ),
        _Action(
          tooltip: 'Mais 15 min',
          onTap: () => onAdjusted(15),
          child: Text(
            '+15',
            style: AppTypography.labelStrong.copyWith(color: AppColors.ink2),
          ),
        ),
        _Action(
          tooltip: 'Concluir',
          onTap: onDone,
          child: const AppIcon(
            iconData: AppIcons.check,
            size: AppSpacing.s4,
            color: AppColors.ink2,
          ),
        ),
      ],
    );
  }
}

/// What a waiting block says in place of its progress bar.
///
/// The hour came and nothing started, because a flexible block waits for the
/// user. Two answers and nothing else: begin it now, or fifteen minutes more,
/// after which it asks again.
class _StartPrompt extends StatelessWidget {
  const _StartPrompt({this.onStarted, this.onSnoozed, super.key});

  final VoidCallback? onStarted;
  final VoidCallback? onSnoozed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Hora de começar',
            style: AppTypography.label.copyWith(color: AppColors.ink2),
          ),
        ),
        if (onSnoozed != null)
          _Action(
            tooltip: 'Esperar 15 min',
            onTap: onSnoozed,
            child: Text(
              '15 min',
              style: AppTypography.labelStrong.copyWith(color: AppColors.ink2),
            ),
          ),
        if (onStarted != null)
          _Action(
            tooltip: 'Começar',
            onTap: onStarted,
            child: const AppIcon(
              iconData: AppIcons.play,
              size: AppSpacing.s4,
              color: AppColors.ink,
            ),
          ),
      ],
    );
  }
}

/// One quiet button in [EventControls].
class _Action extends StatelessWidget {
  const _Action({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;

  /// Null when the button cannot do anything right now.
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: AppSpacing.s5,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: AppSpacing.s8 + AppSpacing.s1,
          height: AppSpacing.s8,
          child: Center(child: child),
        ),
      ),
    );
  }
}
