import 'package:bloc/bloc.dart';
import 'package:chat/src/data/chat_failure.dart';
import 'package:chat/src/data/chat_repository.dart';
import 'package:chat/src/models/models.dart';
import 'package:equatable/equatable.dart';

part 'threads_event.dart';
part 'threads_state.dart';

/// {@template threads_bloc}
/// Holds the timeline.
///
/// Everything about when things happen is worked out on the server, so this
/// mostly forwards and redraws. There is one optimistic write left, solving,
/// because the card has already flown off the screen by the time the request
/// goes out.
/// {@endtemplate}
class ThreadsBloc extends Bloc<ThreadsEvent, ThreadsState> {
  /// {@macro threads_bloc}
  ThreadsBloc({required this._chatRepository}) : super(const ThreadsState()) {
    on<ThreadsRequested>(_onRequested);
    on<ThreadScheduled>(_onScheduled);
    on<ThreadMoved>(_onMoved);
    on<ThreadSolved>(_onSolved);
    on<GuardAnswered>(_onGuardAnswered);
    on<GuardDismissed>(_onGuardDismissed);
    on<SyncWatched>(_onSyncWatched);
    on<SyncRetried>(_onSyncRetried);
  }

  final ChatRepository _chatRepository;

  Future<void> _onRequested(
    ThreadsRequested event,
    Emitter<ThreadsState> emit,
  ) async {
    emit(state.copyWith(status: ThreadsStatus.loading, clearFailure: true));

    try {
      emit(
        state.copyWith(
          status: ThreadsStatus.success,
          cards: await _chatRepository.fetchThreads(),
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      emit(_failed(error));
    }
  }

  /// The state after something the server refused.
  ///
  /// The refusal is kept as the server wrote it, because the server is the
  /// one that knows what went wrong. Every write on this screen is all or
  /// nothing, so the cards already on it are still the true ones.
  ThreadsState _failed(Object error) {
    return state.copyWith(
      status: ThreadsStatus.failure,
      failure: ChatFailure.from(error).message,
      guardBusy: false,
      clearGuard: true,
    );
  }

  /// Writes something down, and draws the timeline with it already in place.
  Future<void> _onScheduled(
    ThreadScheduled event,
    Emitter<ThreadsState> emit,
  ) async {
    try {
      final cards = await _chatRepository.createScheduled(
        message: event.message,
        durationMinutes: event.durationMinutes,
        fixed: event.fixed,
        startTime: event.startTime,
      );

      emit(
        state.copyWith(
          status: ThreadsStatus.success,
          cards: cards,
          clearFailure: true,
        ),
      );

      add(const SyncWatched());
    } on Object catch (error) {
      emit(_failed(error));
    }
  }

  /// Sends a drop and draws what the day became.
  ///
  /// Nothing is applied on screen first. A drop changes the hour of
  /// everything it displaced and only the server knows what those hours are,
  /// so guessing at them would mean drawing a day that is about to be
  /// replaced by a different one.
  Future<void> _onMoved(ThreadMoved event, Emitter<ThreadsState> emit) async {
    final card = state.bySlug(event.slug);
    if (card == null || !card.isInteractive) return;

    try {
      final outcome = await _chatRepository.moveThread(
        event.slug,
        event.index,
      );

      // A guard means the server did not move anything, so the cards that
      // come back are the ones that were already on screen.
      emit(
        outcome.guard == null
            ? state.copyWith(cards: outcome.cards, clearFailure: true)
            : state.copyWith(
                cards: outcome.cards,
                guard: outcome.guard,
                clearFailure: true,
              ),
      );

      // The drop has landed. Whether it reached Google is a separate
      // question, asked behind the answer the finger was waiting for.
      if (outcome.guard == null) add(const SyncWatched());
    } on Object catch (error) {
      emit(_failed(error));
    }
  }

  /// Waits for the calendar and puts the popup up if it fell behind.
  ///
  /// Its own event so that it runs after the change it follows rather than
  /// inside it. Nothing on screen waits for this, and when it comes back with
  /// nothing to say, which is nearly always, it emits nothing at all.
  Future<void> _onSyncWatched(
    SyncWatched event,
    Emitter<ThreadsState> emit,
  ) async {
    try {
      final outcome = await _chatRepository.awaitSync();
      if (outcome.ok || outcome.guard == null) return;

      // Never over an open question. The user is in the middle of answering
      // one, and this one will still be true when they are done.
      if (state.guard != null) return;

      emit(state.copyWith(guard: outcome.guard));
    } on Object catch (_) {
      // A sync check that cannot be made says nothing. The day on screen is
      // right either way, and a popup about the popup helps nobody.
    }
  }

  /// Pushes the day at the calendar again, from the popup's one button.
  Future<void> _onSyncRetried(
    SyncRetried event,
    Emitter<ThreadsState> emit,
  ) async {
    emit(state.copyWith(guardBusy: true));

    try {
      final outcome = await _chatRepository.retrySync();

      emit(
        outcome.ok || outcome.guard == null
            ? state.copyWith(guardBusy: false, clearGuard: true)
            : state.copyWith(guard: outcome.guard, guardBusy: false),
      );
    } on Object catch (error) {
      emit(_failed(error).copyWith(guardBusy: false, clearGuard: true));
    }
  }

  /// Sends the button the user tapped on a guard, and draws what comes back.
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
                cards: outcome.cards,
                guardBusy: false,
                clearGuard: true,
              )
            : state.copyWith(guard: outcome.guard, guardBusy: false),
      );

      if (outcome.guard == null) add(const SyncWatched());
    } on Object catch (error) {
      // The guard closes rather than sitting there looking live. Nothing was
      // applied, so the timeline on screen is still the true one.
      emit(_failed(error));
    }
  }

  /// Drops a guard without answering it, which changes nothing anywhere.
  void _onGuardDismissed(GuardDismissed event, Emitter<ThreadsState> emit) {
    emit(state.copyWith(clearGuard: true, guardBusy: false));
  }

  /// Takes a thread off the timeline, then writes it.
  ///
  /// This one lands on screen first: the card has already been thrown off by
  /// the time the request goes out, and a failure puts it back rather than
  /// leaving a thread the user thinks is solved.
  Future<void> _onSolved(ThreadSolved event, Emitter<ThreadsState> emit) async {
    final before = state.cards;
    final card = state.bySlug(event.slug);
    if (card == null || !card.isInteractive) return;

    if (event.solved) {
      emit(
        state.copyWith(
          cards: before.where((it) => it.slug != event.slug).toList(),
        ),
      );
    }

    try {
      emit(
        state.copyWith(
          cards: await _chatRepository.setSolved(
            event.slug,
            solved: event.solved,
          ),
          clearFailure: true,
        ),
      );

      add(const SyncWatched());
    } on Object catch (error) {
      // Solving is the one write that lands on screen first, so it is also
      // the one that has to be put back.
      emit(_failed(error).copyWith(cards: before));
    }
  }
}
