part of 'threads_bloc.dart';

/// {@template threads_event}
/// Base class for events handled by [ThreadsBloc].
/// {@endtemplate}
sealed class ThreadsEvent extends Equatable {
  /// {@macro threads_event}
  const ThreadsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the timeline, or reloads it after the user returns to home.
final class ThreadsRequested extends ThreadsEvent {
  /// {@macro threads_event}
  const ThreadsRequested();
}

/// Writes something down and puts it on the timeline.
///
/// No conversation. The sheet asked how long it takes and whether the hour is
/// the point of it, which is everything the server needs to give it one.
final class ThreadScheduled extends ThreadsEvent {
  /// {@macro threads_event}
  const ThreadScheduled({
    required this.message,
    required this.durationMinutes,
    required this.fixed,
    this.startTime,
  });

  /// What the user wrote.
  final String message;

  /// How long it takes.
  final int durationMinutes;

  /// Whether the hour is the point of it.
  final bool fixed;

  /// The hour, when the user picked one. Only a fixed block does.
  final DateTime? startTime;

  @override
  List<Object?> get props => [message, durationMinutes, fixed, startTime];
}

/// Moves one card to [index] in the day's single list.
///
/// One number, because there is one list. The server turns it into hours for
/// everything the drop disturbed, so the app waits for the answer rather than
/// guessing at the new times itself.
final class ThreadMoved extends ThreadsEvent {
  /// {@macro threads_event}
  const ThreadMoved({required this.slug, required this.index});

  /// The card that was dragged.
  final String slug;

  /// Where it was dropped, counted from the top with itself taken out.
  final int index;

  @override
  List<Object?> get props => [slug, index];
}

/// Sends back the button the user tapped on a guard.
///
/// The action is the server's own object, posted verbatim. The app never
/// reads it: a guard's buttons are drawn from what the server sent and
/// answered with what it sent.
final class GuardAnswered extends ThreadsEvent {
  /// {@macro threads_event}
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
final class SyncWatched extends ThreadsEvent {
  /// {@macro threads_event}
  const SyncWatched();
}

/// Pushes whatever did not reach the calendar at it again.
///
/// The one button on the sync popup. It names nothing: the retry is
/// everything that fell behind, whatever that turned out to be.
final class SyncRetried extends ThreadsEvent {
  /// {@macro threads_event}
  const SyncRetried();
}

/// Closes a guard without answering it.
///
/// Nothing was applied while it was open, so there is nothing to undo.
final class GuardDismissed extends ThreadsEvent {
  /// {@macro threads_event}
  const GuardDismissed();
}

/// Marks a thread solved, or puts a solved one back.
///
/// Solved is the one word for this in the app, the API, and the store: a
/// thread dragged aside on the timeline, one closed out from the chat, and
/// one the agent closed are the same thing.
final class ThreadSolved extends ThreadsEvent {
  /// {@macro threads_event}
  const ThreadSolved(this.slug, {required this.solved});

  /// The thread that was dragged aside, or recovered.
  final String slug;

  /// Whether it is now solved.
  final bool solved;

  @override
  List<Object?> get props => [slug, solved];
}
