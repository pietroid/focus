import 'package:bloc/bloc.dart';
import 'package:chat/src/data/chat_repository.dart';
import 'package:chat/src/models/models.dart';
import 'package:equatable/equatable.dart';

part 'threads_event.dart';
part 'threads_state.dart';

/// {@template threads_bloc}
/// Holds the home screen's list of threads.
/// {@endtemplate}
class ThreadsBloc extends Bloc<ThreadsEvent, ThreadsState> {
  /// {@macro threads_bloc}
  ThreadsBloc({required this._chatRepository}) : super(const ThreadsState()) {
    on<ThreadsRequested>(_onRequested);
    on<ThreadMoved>(_onMoved);
    on<ThreadSolved>(_onSolved);
    on<GuardAnswered>(_onGuardAnswered);
    on<GuardDismissed>(_onGuardDismissed);
  }

  final ChatRepository _chatRepository;

  Future<void> _onRequested(
    ThreadsRequested event,
    Emitter<ThreadsState> emit,
  ) async {
    emit(state.copyWith(status: ThreadsStatus.loading));

    try {
      final threads = await _chatRepository.fetchThreads();
      emit(
        state.copyWith(status: ThreadsStatus.success, threads: threads),
      );
    } on Exception catch (_) {
      emit(state.copyWith(status: ThreadsStatus.failure));
    }
  }

  Future<void> _onMoved(ThreadMoved event, Emitter<ThreadsState> emit) async {
    final index = state.threads.indexWhere((t) => t.slug == event.slug);
    if (index == -1) return;
    final moved = state.threads[index];

    // A calendar card is drawn from the event and has nowhere else to be.
    if (!moved.isInteractive) return;

    final before = state.threads;

    // Rebuild every list from the one on screen, drop the thread out of the
    // list it was in, and put it back at the index it was dropped on.
    final buckets = <ThreadBucket, List<ThreadSummary>>{
      for (final bucket in ThreadBucket.values)
        bucket: state
            .inBucket(bucket)
            .where((t) => t.slug != event.slug && t.isInteractive)
            .toList(),
    };

    final target = buckets[event.bucket]!;
    target.insert(
      event.index.clamp(0, target.length),
      moved.copyWith(bucket: event.bucket),
    );

    // Calendar cards and solved threads are not part of the placement: the
    // first are not the user's to move and the second are not on screen. Both
    // are kept so the list the app draws is still the whole list.
    final reordered = [
      for (final bucket in ThreadBucket.values) ...buckets[bucket]!,
      ...state.threads.where((t) => t.solved || !t.isInteractive),
    ];

    emit(state.copyWith(threads: reordered));

    try {
      final outcome = await _chatRepository.savePlacements({
        for (final entry in buckets.entries)
          entry.key: entry.value.map((t) => t.slug).toList(),
      });

      // A guard means the server did not move anything. The card goes back to
      // where it was and the question takes its place: leaving the card in
      // its new list while asking whether it may go there would be the screen
      // answering on the user's behalf.
      emit(
        outcome.guard == null
            ? state.copyWith(threads: outcome.cards)
            : state.copyWith(threads: before, guard: outcome.guard),
      );
    } on Exception catch (_) {
      // The drop stays on screen. A reload is what puts it back, and that is
      // better than yanking a card out from under the finger that moved it.
      emit(state.copyWith(status: ThreadsStatus.failure));
    }
  }

  /// Sends the button the user tapped on a guard, and draws what comes back.
  ///
  /// The answer is either the day as it now stands or the next question, and
  /// the two are handled the same way, because a guard that asks twice is the
  /// same guard: one move, answered a piece at a time.
  Future<void> _onGuardAnswered(
    GuardAnswered event,
    Emitter<ThreadsState> emit,
  ) async {
    emit(state.copyWith(guardBusy: true));

    try {
      final outcome = await _chatRepository.applyTiming(event.action);

      emit(
        outcome.guard == null
            ? state.copyWith(
                threads: outcome.cards,
                guardBusy: false,
                clearGuard: true,
              )
            : state.copyWith(guard: outcome.guard, guardBusy: false),
      );
    } on Exception catch (_) {
      // The guard closes rather than sitting there looking live. Nothing was
      // applied, so the timeline on screen is still the true one.
      emit(
        state.copyWith(
          status: ThreadsStatus.failure,
          guardBusy: false,
          clearGuard: true,
        ),
      );
    }
  }

  /// Drops a guard without answering it, which changes nothing anywhere.
  void _onGuardDismissed(GuardDismissed event, Emitter<ThreadsState> emit) {
    emit(state.copyWith(clearGuard: true, guardBusy: false));
  }

  /// Flips one thread's solved flag on screen, then writes it.
  ///
  /// A thread that changes this flag moves between two screens rather than
  /// between two places on one, so a failed write is put back: leaving a card
  /// off the timeline because the request never landed is the one outcome the
  /// user cannot see and cannot undo.
  Future<void> _onSolved(ThreadSolved event, Emitter<ThreadsState> emit) async {
    final before = state.threads;
    final index = before.indexWhere((t) => t.slug == event.slug);
    if (index == -1 || before[index].solved == event.solved) return;

    if (!before[index].isInteractive) return;

    final threads = [...before];
    threads[index] = threads[index].copyWith(solved: event.solved);
    emit(state.copyWith(threads: threads));

    try {
      await _chatRepository.setSolved(event.slug, solved: event.solved);
    } on Exception catch (_) {
      emit(state.copyWith(status: ThreadsStatus.failure, threads: before));
    }
  }
}
