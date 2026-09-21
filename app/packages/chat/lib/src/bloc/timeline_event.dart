part of 'timeline_bloc.dart';

/// {@template timeline_bloc_event}
/// Base class for events handled by [TimelineBloc].
///
/// Named for the bloc rather than for the domain, because the domain already
/// has events: the blocks of time this draws. One of these is something that
/// happened to the screen, not something on the calendar.
/// {@endtemplate}
sealed class TimelineBlocEvent extends Equatable {
  /// {@macro timeline_bloc_event}
  const TimelineBlocEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the day, or reloads it after the user returns to home.
final class TimelineRequested extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const TimelineRequested();
}

/// Writes something down and puts it on the timeline.
///
/// No conversation. The sheet asked how long it takes and whether the hour is
/// the point of it, which is everything the server needs to give it one.
final class EventCreated extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventCreated({
    required this.title,
    required this.durationMinutes,
    required this.fixed,
    this.startTime,
  });

  /// What the user wrote, which is what the block is called.
  final String title;

  /// How long it takes.
  final int durationMinutes;

  /// Whether the hour is the point of it.
  final bool fixed;

  /// The hour, when the user picked one. Only a fixed block does.
  final DateTime? startTime;

  @override
  List<Object?> get props => [title, durationMinutes, fixed, startTime];
}

/// Moves one card to [index] in the day's single list.
///
/// One number, because there is one list. The server turns it into hours for
/// everything the drop disturbed, so the app waits for the answer rather than
/// guessing at the new times itself.
final class EventMoved extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventMoved({required this.id, required this.index});

  /// The card that was dragged.
  final String id;

  /// Where it was dropped, counted from the top with itself taken out.
  final int index;

  @override
  List<Object?> get props => [id, index];
}

/// Sends back the button the user tapped on a guard.
///
/// The action is the server's own object, posted verbatim. The app never
/// reads it: a guard's buttons are drawn from what the server sent and
/// answered with what it sent.
final class GuardAnswered extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const GuardAnswered(this.action);

  /// The action the tapped component carried.
  final Map<String, dynamic> action;

  @override
  List<Object?> get props => [action];
}

/// Asks whether the calendar kept up with the last change.
///
/// Fired after every change and awaited by nobody: the day is already on
/// screen, and this only decides whether a popup goes over it. The app never
/// works out the answer itself, because what is still queued for Google is
/// the server's to know.
final class SyncWatched extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const SyncWatched();
}

/// Pushes whatever did not reach the calendar at it again.
///
/// The one button on the sync popup. It names nothing: the retry is
/// everything that fell behind, whatever that turned out to be.
final class SyncRetried extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const SyncRetried();
}

/// Closes a guard without answering it.
///
/// Nothing was applied while it was open, so there is nothing to undo.
final class GuardDismissed extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const GuardDismissed();
}

/// Takes a block off the day.
///
/// The hour it had goes back to the day and the rest of it closes up over the
/// space. A conversation about the block, if there was one, is closed with
/// it: something the user is finished with is not something they still have
/// an open question about.
final class EventFinished extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventFinished(this.id);

  /// The card that was carried out of the timeline.
  final String id;

  @override
  List<Object?> get props => [id];
}
