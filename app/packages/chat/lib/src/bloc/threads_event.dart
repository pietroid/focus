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

/// Loads the thread list, or reloads it after the user returns to home.
final class ThreadsRequested extends ThreadsEvent {
  /// {@macro threads_event}
  const ThreadsRequested();
}

/// Moves one thread to [index] of [bucket], from wherever it was.
///
/// The drop is applied to the list on screen first and written to the server
/// after. A drag that had to wait for a round trip before it looked like it
/// had happened would feel broken, and the worst case if the write fails is
/// that the next load puts the thread back.
final class ThreadMoved extends ThreadsEvent {
  /// {@macro threads_event}
  const ThreadMoved({
    required this.slug,
    required this.bucket,
    required this.index,
  });

  /// The thread that was dragged.
  final String slug;

  /// The list it was dropped into.
  final ThreadBucket bucket;

  /// Its place in that list, counted after it has been taken out of wherever
  /// it came from.
  final int index;

  @override
  List<Object?> get props => [slug, bucket, index];
}

/// Marks a thread solved, or puts a solved one back on the timeline.
///
/// Solved is the one word for this in the app, the API, and the store: a
/// thread dragged aside on the timeline, one closed out from the chat, and
/// one the agent closed are the same thing, and giving them separate names
/// was how three ways of solving the same thread stopped agreeing.
///
/// Like [ThreadMoved] this lands on screen first and is written after. The
/// card has already flown off by the time the request goes out, and a failure
/// puts it back rather than leaving a thread the user thinks is solved.
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
