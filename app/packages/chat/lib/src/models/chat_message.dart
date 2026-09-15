import 'package:equatable/equatable.dart';

/// Who wrote a message.
enum MessageRole {
  /// The person using the app.
  user,

  /// The agent answering them.
  agent;

  /// Parses the role as the API spells it, defaulting to [agent].
  static MessageRole fromJson(String? value) {
    return value == 'user' ? MessageRole.user : MessageRole.agent;
  }
}

/// {@template chat_message}
/// A single turn in a thread.
/// {@endtemplate}
class ChatMessage extends Equatable {
  /// {@macro chat_message}
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  /// Creates a [ChatMessage] from the API's JSON.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      role: MessageRole.fromJson(json['role'] as String?),
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  /// A message the user has typed but the server has not acknowledged yet.
  ///
  /// Carries a local id so the optimistic copy can be told apart from the one
  /// that comes back, and is otherwise an ordinary message.
  factory ChatMessage.pending(String text) {
    final now = DateTime.now();
    return ChatMessage(
      id: 'pending-${now.microsecondsSinceEpoch}',
      role: MessageRole.user,
      text: text,
      createdAt: now,
    );
  }

  /// Stable id, derived by the server from the role and timestamp.
  final String id;

  /// Who wrote the message.
  final MessageRole role;

  /// The message body.
  final String text;

  /// When the message was written, in local time.
  final DateTime createdAt;

  /// Whether this message came from the person using the app.
  bool get isUser => role == MessageRole.user;

  @override
  List<Object?> get props => [id, role, text, createdAt];
}
