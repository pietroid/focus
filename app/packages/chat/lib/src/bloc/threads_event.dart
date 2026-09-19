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
