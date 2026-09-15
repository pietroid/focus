import 'package:bloc/bloc.dart';
import 'package:chat/src/data/chat_repository.dart';
import 'package:chat/src/models/models.dart';
import 'package:equatable/equatable.dart';

part 'chat_event.dart';
part 'chat_state.dart';

/// {@template chat_bloc}
/// Drives one chat screen.
///
/// A message is shown the moment it is sent, before the server has seen it, so
/// the screen never looks like it dropped what the user typed. The agent's
/// answer is what the skeleton waits for.
/// {@endtemplate}
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  /// {@macro chat_bloc}
  ChatBloc({required this._chatRepository}) : super(const ChatState()) {
    on<ChatThreadRequested>(_onThreadRequested);
    on<ChatMessageSent>(_onMessageSent);
  }

  final ChatRepository _chatRepository;

  Future<void> _onThreadRequested(
    ChatThreadRequested event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(status: ChatStatus.loading, slug: event.slug));

    try {
      final thread = await _chatRepository.fetchThread(event.slug);
      emit(_loaded(thread));
    } on Exception catch (_) {
      emit(
        state.copyWith(
          status: ChatStatus.failure,
          errorMessage: 'Could not open this thread.',
        ),
      );
    }
  }

  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty) return;

    final pending = ChatMessage.pending(text);
    final slug = state.slug;

    emit(
      state.copyWith(
        status: ChatStatus.awaitingReply,
        title: state.title.isEmpty ? text : state.title,
        messages: [...state.messages, pending],
      ),
    );

    try {
      final thread = slug == null
          ? await _chatRepository.createThread(text)
          : await _chatRepository.sendMessage(slug, text);

      emit(_loaded(thread));
    } on Exception catch (_) {
      // Drop the optimistic copy: leaving it on screen under an error would
      // claim the message was sent when it was not.
      emit(
        state.copyWith(
          status: ChatStatus.failure,
          messages: state.messages
              .where((message) => message.id != pending.id)
              .toList(),
          errorMessage: 'Could not send that message.',
        ),
      );
    }
  }

  ChatState _loaded(Thread thread) {
    return ChatState(
      status: ChatStatus.ready,
      slug: thread.slug,
      title: thread.title,
      messages: thread.messages,
    );
  }
}
