part of 'chat_bloc.dart';

/// {@template chat_event}
/// Base class for events handled by [ChatBloc].
/// {@endtemplate}
sealed class ChatEvent extends Equatable {
  /// {@macro chat_event}
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Loads an existing thread the user opened from the home screen.
final class ChatThreadRequested extends ChatEvent {
  /// {@macro chat_event}
  const ChatThreadRequested(this.slug);

  /// The thread to load.
  final String slug;

  @override
  List<Object?> get props => [slug];
}

/// Sends a message.
///
/// Starts a new thread when the chat has no slug yet, which is the case when
/// the user has just typed the first message on the home screen.
final class ChatMessageSent extends ChatEvent {
  /// {@macro chat_event}
  const ChatMessageSent(this.text);

  /// What the user typed.
  final String text;

  @override
  List<Object?> get props => [text];
}

/// Confirms or rejects a pending tool call.
final class ChatToolConfirmed extends ChatEvent {
  /// {@macro chat_event}
  const ChatToolConfirmed({
    required this.toolCallId,
    required this.confirmed,
    this.arguments,
  });

  /// The id of the pending tool call.
  final String toolCallId;

  /// Whether the user confirmed the action.
  final bool confirmed;

  /// Optional override of the original tool arguments.
  final Map<String, dynamic>? arguments;

  @override
  List<Object?> get props => [toolCallId, confirmed, arguments];
}

/// Handles an A2UI action from the rendered component tree.
final class ChatA2uiAction extends ChatEvent {
  /// {@macro chat_event}
  const ChatA2uiAction(this.action);

  /// The action payload emitted by the component.
  final Map<String, dynamic> action;

  @override
  List<Object?> get props => [action];
}
