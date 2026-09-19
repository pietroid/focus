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

    // Rebuild every list from the one on screen, drop the thread out of the
    // list it was in, and put it back at the index it was dropped on.
    final buckets = <ThreadBucket, List<ThreadSummary>>{
      for (final bucket in ThreadBucket.values)
        bucket: state.threads
            .where((t) => t.bucket == bucket && t.slug != event.slug)
            .toList(),
    };

    final target = buckets[event.bucket]!;
    target.insert(
      event.index.clamp(0, target.length),
      moved.copyWith(bucket: event.bucket),
    );

    final reordered = [
      for (final bucket in ThreadBucket.values) ...buckets[bucket]!,
    ];

    emit(state.copyWith(threads: reordered));

    try {
      await _chatRepository.savePlacements({
        for (final entry in buckets.entries)
          entry.key: entry.value.map((t) => t.slug).toList(),
      });
    } on Exception catch (_) {
      // The drop stays on screen. A reload is what puts it back, and that is
      // better than yanking a card out from under the finger that moved it.
      emit(state.copyWith(status: ThreadsStatus.failure));
    }
  }
}
