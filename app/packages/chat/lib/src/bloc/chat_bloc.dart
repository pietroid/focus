import 'dart:convert';
import 'dart:developer';

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
  ChatBloc({required this.chatRepository}) : super(const ChatState()) {
    on<ChatThreadRequested>(_onThreadRequested);
    on<ChatMessageSent>(_onMessageSent);
    on<ChatToolConfirmed>(_onToolConfirmed);
    on<ChatA2uiAction>(_onA2uiAction);
  }

  /// Repository used to read and write threads.
  final ChatRepository chatRepository;

  Future<void> _onThreadRequested(
    ChatThreadRequested event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(status: ChatStatus.loading, slug: event.slug));

    try {
      final thread = await chatRepository.fetchThread(event.slug);
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
          ? await chatRepository.createThread(text)
          : await chatRepository.sendMessage(slug, text);

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

  Future<void> _onToolConfirmed(
    ChatToolConfirmed event,
    Emitter<ChatState> emit,
  ) async {
    final slug = state.slug;
    if (slug == null) return;

    log(
      '[ChatBloc] confirming tool',
      name: 'chat_bloc',
      error: {
        'toolCallId': event.toolCallId,
        'confirmed': event.confirmed,
        'arguments': event.arguments,
        'slug': slug,
      },
    );

    emit(
      state.copyWith(
        status: ChatStatus.awaitingAction,
      ),
    );

    try {
      final thread = await chatRepository.confirmTool(
        slug: slug,
        toolCallId: event.toolCallId,
        confirmed: event.confirmed,
        arguments: event.arguments,
      );

      emit(_loaded(thread));
    } on Exception catch (error, stackTrace) {
      log(
        '[ChatBloc] confirmTool failed',
        name: 'chat_bloc',
        error: error,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          // Revert to the previous screen so the user can retry the action.
          status: ChatStatus.ready,
          errorMessage: 'Could not confirm the action. Please try again.',
        ),
      );
    }
  }

  Future<void> _onA2uiAction(
    ChatA2uiAction event,
    Emitter<ChatState> emit,
  ) async {
    final action = event.action;
    final type = action['type'] as String?;

    log(
      '[ChatBloc] handling A2UI action',
      name: 'chat_bloc',
      error: {
        'type': type,
        'tool': action['tool'],
        'requiresConfirmation': action['requiresConfirmation'],
        '_toolCallId': action['_toolCallId'],
        'arguments': action['arguments'],
        'fullAction': action,
      },
    );

    switch (type) {
      case 'tool':
        final requiresConfirmation =
            action['requiresConfirmation'] as bool? ?? false;
        final slug = state.slug;
        if (slug == null) return;

        // Disable every action immediately so the user cannot double-tap.
        emit(state.copyWith(status: ChatStatus.awaitingAction));

        var toolCallId = action['_toolCallId'] as String? ??
            state.pendingToolCall?.id ??
            '';

        if (toolCallId.isEmpty) {
          // The model emitted a tool action without a backend pending call.
          // Treat it as a new user request so the agent can process it through
          // the proper tool loop and return a confirmable action.
          final toolName = action['tool'] as String? ?? '';
          final arguments = action['arguments'] as Map<String, dynamic>? ?? {};
          add(ChatMessageSent('Please run $toolName with $arguments'));
          break;
        }

        if (requiresConfirmation) {
          emit(
            state.copyWith(
              pendingToolCall: PendingToolCall(
                id: toolCallId,
                name: action['tool'] as String? ?? '',
                arguments: jsonEncode(
                  action['arguments'] as Map<String, dynamic>? ?? {},
                ),
              ),
            ),
          );
        } else {
          add(
            ChatToolConfirmed(
              toolCallId: toolCallId,
              confirmed: true,
              arguments: action['arguments'] as Map<String, dynamic>?,
            ),
          );
        }
        break;
      case 'reply':
        final text = action['text'] as String?;
        if (text != null && text.isNotEmpty) {
          add(ChatMessageSent(text));
        }
        break;
      case 'dismiss':
        // Reset to the idle state so actions are re-enabled and the skeleton
        // is hidden.
        emit(
          state.copyWith(
            status: ChatStatus.ready,
            pendingToolCall: null,
          ),
        );
        break;
      case 'openUrl':
      // URLs are handled by the presentation layer via url_launcher.
      default:
        break;
    }
  }

  ChatState _loaded(Thread thread) {
    final pending = thread.messages
        .map((message) => message.metadata?.pendingToolCall)
        .whereType<PendingToolCall>()
        .lastOrNull;

    return ChatState(
      status: ChatStatus.ready,
      slug: thread.slug,
      title: thread.title,
      messages: thread.messages,
      pendingToolCall: pending,
    );
  }
}
