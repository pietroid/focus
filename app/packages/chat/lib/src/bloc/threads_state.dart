part of 'threads_bloc.dart';

/// The status of the timeline.
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
/// The state of the timeline.
/// {@endtemplate}
final class ThreadsState extends Equatable {
  /// {@macro threads_state}
  const ThreadsState({
    this.status = ThreadsStatus.initial,
    this.cards = const [],
    this.guard,
    this.guardBusy = false,
    this.failure,
  });

  /// The status of the list.
  final ThreadsStatus status;

  /// Every card on the timeline, earliest first.
  ///
  /// One list, in clock order, exactly as the server sent it. The sections
  /// the screen draws are cut out of this rather than stored alongside it,
  /// which is why nothing here ever has to be kept in step with anything.
  final List<ThreadSummary> cards;

  /// The question a move raised, if one is still open.
  ///
  /// While this is set nothing about the move has happened on the server.
  final A2uiComponent? guard;

  /// Whether the guard's last answer is still in flight.
  final bool guardBusy;

  /// Why the last thing the screen tried did not happen.
  ///
  /// The server's own sentence, kept as written. It is already in the user's
  /// language and already says the useful part — that it was the agenda that
  /// did not answer, rather than something about this screen.
  final String? failure;

  /// The cards in [section], in the order they are drawn.
  List<ThreadSummary> inSection(TimelineSection section) {
    return cards.where((card) => card.section == section).toList();
  }

  /// The card with [slug], or null if the timeline does not have it.
  ThreadSummary? bySlug(String slug) {
    for (final card in cards) {
      if (card.slug == slug) return card;
    }

    return null;
  }

  /// Where [slug] sits in the one list, or -1.
  int indexOf(String slug) => cards.indexWhere((card) => card.slug == slug);

  /// Whether the first load is still in flight.
  ///
  /// A reload with cards already on screen is not a loading state: replacing
  /// the list with a spinner every time the user comes back from a chat would
  /// flash the screen for no reason.
  bool get isInitialLoad => status == ThreadsStatus.loading && cards.isEmpty;

  /// Returns a copy with the given fields replaced.
  ///
  /// [clearGuard] takes the guard away, which a null [guard] cannot: the
  /// whole point of most of these copies is to leave it exactly as it is.
  ThreadsState copyWith({
    ThreadsStatus? status,
    List<ThreadSummary>? cards,
    A2uiComponent? guard,
    bool? guardBusy,
    String? failure,
    bool clearGuard = false,
    bool clearFailure = false,
  }) {
    return ThreadsState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      guard: clearGuard ? null : guard ?? this.guard,
      guardBusy: guardBusy ?? this.guardBusy,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [status, cards, guard, guardBusy, failure];
}
