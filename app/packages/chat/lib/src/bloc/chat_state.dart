part of 'chat_bloc.dart';

/// Sentinel used by [ChatState.copyWith] to distinguish "leave as is" from
/// "clear the field".
const Object _clear = Object();

/// The status of a chat.
enum ChatStatus {
  /// Nothing has been requested yet.
  initial,

  /// An existing thread is being fetched.
  loading,

  /// The thread is on screen and idle.
  ready,

  /// The user's message is on screen and the agent has not answered yet.
  awaitingReply,

  /// An A2UI action has been chosen and the agent has not answered yet.
  awaitingAction,

  /// Something failed.
  failure,
}

/// {@template chat_state}
/// The state of one chat screen.
/// {@endtemplate}
final class ChatState extends Equatable {
  /// {@macro chat_state}
  const ChatState({
    this.status = ChatStatus.initial,
    this.slug,
    this.title = '',
    this.messages = const [],
    this.pendingToolCall,
    this.errorMessage,
  });

  /// The status of the chat.
  final ChatStatus status;

  /// The thread's id, once the server has created it.
  ///
  /// Null while the first message of a brand new thread is still in flight.
  final String? slug;

  /// The thread's one-line name.
  final String title;

  /// Every message on screen, oldest first, including one the server has not
  /// acknowledged yet.
  final List<ChatMessage> messages;

  /// A tool call awaiting user confirmation, surfaced as a modal/sheet.
  final PendingToolCall? pendingToolCall;

  /// What went wrong, when [status] is [ChatStatus.failure].
  final String? errorMessage;

  /// Whether to show the agent's reply skeleton at the end of the list.
  bool get isAwaitingReply => status == ChatStatus.awaitingReply;

  /// Whether an A2UI action is in flight and the action buttons are disabled.
  bool get isAwaitingAction => status == ChatStatus.awaitingAction;

  /// Whether any agent response is being waited for.
  bool get isAwaiting => isAwaitingReply || isAwaitingAction;

  /// Returns a copy with the given fields replaced.
  ///
  /// [errorMessage] and [pendingToolCall] clear unless they are passed, so a
  /// retry or dismiss does not leave stale state on screen.
  ChatState copyWith({
    ChatStatus? status,
    String? slug,
    String? title,
    List<ChatMessage>? messages,
    Object? pendingToolCall = _clear,
    String? errorMessage,
  }) {
    return ChatState(
      status: status ?? this.status,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      pendingToolCall: pendingToolCall == _clear
          ? this.pendingToolCall
          : pendingToolCall as PendingToolCall?,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, slug, title, messages, pendingToolCall, errorMessage];
}
