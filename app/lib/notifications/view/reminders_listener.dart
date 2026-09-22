import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:notifications/notifications.dart';

/// {@template reminders_listener}
/// Keeps the reminder queue in step with the day, and opens what a reminder
/// was about when it is tapped.
///
/// The queue is re-synced when the app comes back to the foreground and
/// whenever a block on the timeline is added, moved, renamed, paused or taken
/// off, whoever did it: the sheet, a drag, or a conversation that booked
/// something.
///
/// It is also where permission is asked, and only once: the first time a
/// block appears on a day the app had already loaded, which is the first
/// moment a reminder would be for something.
/// {@endtemplate}
class RemindersListener extends StatefulWidget {
  /// {@macro reminders_listener}
  const RemindersListener({required this.child, super.key});

  /// The screen underneath.
  final Widget child;

  @override
  State<RemindersListener> createState() => _RemindersListenerState();
}

class _RemindersListenerState extends State<RemindersListener>
    with WidgetsBindingObserver {
  late final NotificationScheduler _scheduler;
  late final StreamSubscription<NotificationTap> _taps;

  /// The day as it was last loaded, so a change can be told from a reload.
  late TimelineState _last;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _scheduler = context.read<NotificationScheduler>();
    _last = context.read<TimelineBloc>().state;
    WidgetsBinding.instance.addObserver(this);
    _taps = _scheduler.taps.listen(_open);
    unawaited(_openLaunchTap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_taps.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_scheduler.sync());
  }

  Future<void> _openLaunchTap() async {
    final tap = await _scheduler.launchTap();
    if (tap != null) _open(tap);
  }

  void _open(NotificationTap tap) {
    if (!mounted) return;
    final slug = tap.threadSlug;
    if (slug != null) unawaited(context.push<void>('/chat/$slug'));
  }

  void _onDay(TimelineState current) {
    // A reload passes through loading on its way back. Comparing against
    // that would make every block look new, so only a loaded day counts.
    if (current.status != TimelineStatus.success) return;

    final previous = _last;
    _last = current;
    if (_fingerprint(previous) == _fingerprint(current)) return;

    unawaited(_scheduler.sync());
    if (_gainedBlock(previous, current)) unawaited(_maybeAsk());
  }

  Future<void> _maybeAsk() async {
    if (_asking) return;
    _asking = true;

    try {
      if (!await _scheduler.shouldAskPermission() || !mounted) return;

      if (await _explain(context)) {
        await _scheduler.requestPermission();
      } else {
        await _scheduler.declinePermission();
      }
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TimelineBloc, TimelineState>(
      listener: (context, state) => _onDay(state),
      child: widget.child,
    );
  }
}

/// Everything about the day a reminder depends on, as one string.
///
/// The timeline is fetched again on every minute boundary, and a sync per
/// minute would be a request per minute for nothing. This only changes when
/// a block Focus booked does.
String _fingerprint(TimelineState state) {
  return [
    for (final card in state.cards)
      if (card.managed)
        [
          card.id,
          card.title,
          card.startTime.toIso8601String(),
          card.endTime.toIso8601String(),
          card.pausedAt != null,
        ].join('|'),
  ].join('\n');
}

/// Whether [current] has a block Focus booked that a loaded [previous] did
/// not, which is someone having just put something on the day.
bool _gainedBlock(TimelineState previous, TimelineState current) {
  if (previous.status != TimelineStatus.success) return false;

  final before = {
    for (final card in previous.cards)
      if (card.managed) card.id,
  };

  return current.cards.any((card) => card.managed && !before.contains(card.id));
}

/// One line saying what reminders are for, before the system asks.
///
/// Resolves to true only on the button that turns them on.
Future<bool> _explain(BuildContext context) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (sheetContext) => Material(
      color: AppColors.bg,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.cardRadius),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s6,
            AppSpacing.s5,
            AppSpacing.s6,
            AppSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Quer lembretes?', style: AppTypography.title),
              const SizedBox(height: AppSpacing.s1),
              Text(
                'Aviso quando um bloco começa e dez minutos antes de '
                'acabar, e mando um bom dia e um boa noite.',
                style: AppTypography.body.copyWith(color: AppColors.ink2),
              ),
              const SizedBox(height: AppSpacing.s5),
              AppButton(
                text: 'Ativar lembretes',
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: AppSpacing.s2),
              AppButton.text(
                text: 'Agora não',
                color: AppColors.ink2,
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return accepted ?? false;
}
