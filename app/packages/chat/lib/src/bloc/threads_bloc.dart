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
}
