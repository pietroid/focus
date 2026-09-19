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
  });

  /// The status of the list.
  final ThreadsStatus status;

  /// The threads, most recently updated first.
  final List<ThreadSummary> threads;

  /// The threads in [bucket], in the order they are drawn.
  List<ThreadSummary> inBucket(ThreadBucket bucket) {
    return threads.where((thread) => thread.bucket == bucket).toList();
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
  ThreadsState copyWith({
    ThreadsStatus? status,
    List<ThreadSummary>? threads,
  }) {
    return ThreadsState(
      status: status ?? this.status,
      threads: threads ?? this.threads,
    );
  }

  @override
  List<Object?> get props => [status, threads];
}
