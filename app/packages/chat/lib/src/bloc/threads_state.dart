part of 'threads_bloc.dart';

/// The status of the thread list.
enum ThreadsStatus {
  /// Nothing has been requested yet.
  initial,

  /// The list is being fetched.
  loading,

  /// The list is available.
  success,

  /// The list could not be fetched.
  failure,
}

/// {@template threads_state}
/// The state of the home screen's thread list.
/// {@endtemplate}
final class ThreadsState extends Equatable {
  /// {@macro threads_state}
  const ThreadsState({
    this.status = ThreadsStatus.initial,
    this.threads = const [],
    this.guard,
    this.guardBusy = false,
  });

  /// The status of the list.
  final ThreadsStatus status;

  /// The threads, most recently updated first.
  final List<ThreadSummary> threads;

  /// The question a move raised, if one is still open.
  ///
  /// While this is set, nothing about the move has happened on the server:
  /// the lists in [threads] are the ones that were there before the drag.
  final A2uiComponent? guard;

  /// Whether the guard's last answer is still in flight.
  ///
  /// The rules live on the server, so answering a guard is a round trip. The
  /// buttons go quiet for it rather than letting the same answer be sent
  /// twice.
  final bool guardBusy;

  /// The threads in [bucket], in the order they are drawn.
  ///
  /// Solved threads are not in any bucket. They keep the bucket they were in,
  /// so recovering one puts it back where it was, but the timeline is about
  /// what is still to happen and a solved thread is no longer that.
  List<ThreadSummary> inBucket(ThreadBucket bucket) {
    return threads
        .where((thread) => thread.bucket == bucket && !thread.solved)
        .toList();
  }

  /// The threads that have been solved, newest first.
  List<ThreadSummary> get solved {
    return threads.where((thread) => thread.solved).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// The thread with [slug], or null if the list does not have it.
  ThreadSummary? bySlug(String slug) {
    for (final thread in threads) {
      if (thread.slug == slug) return thread;
    }

    return null;
  }

  /// Whether the first load is still in flight.
  ///
  /// A reload with threads already on screen is not a loading state: replacing
  /// the list with a spinner every time the user comes back from a chat would
  /// flash the screen for no reason.
  bool get isInitialLoad => status == ThreadsStatus.loading && threads.isEmpty;

  /// Returns a copy with the given fields replaced.
  ///
  /// [clearGuard] takes the guard away, which a null [guard] cannot: the
  /// whole point of most of these copies is to leave it exactly as it is.
  ThreadsState copyWith({
    ThreadsStatus? status,
    List<ThreadSummary>? threads,
    A2uiComponent? guard,
    bool? guardBusy,
    bool clearGuard = false,
  }) {
    return ThreadsState(
      status: status ?? this.status,
      threads: threads ?? this.threads,
      guard: clearGuard ? null : guard ?? this.guard,
      guardBusy: guardBusy ?? this.guardBusy,
    );
  }

  @override
  List<Object?> get props => [status, threads, guard, guardBusy];
}
