import 'package:chat/src/models/chat_message.dart';
import 'package:equatable/equatable.dart';

/// Which of the home screen's three lists a thread sits in.
///
/// The bucket is the user's own judgement about when something happens. It is
/// never derived from a date and the agent never sets it: a thread starts in
/// [ThreadBucket.emBreve] and moves only because someone dragged it.
enum ThreadBucket {
  /// What is being done right now.
  agora('agora', 'Agora'),

  /// What is next, but not yet.
  emBreve('em_breve', 'Em breve'),

  /// Parked, on purpose.
  depois('depois', 'Depois');

  const ThreadBucket(this.wire, this.label);

  /// The name the API uses.
  final String wire;

  /// The section header, as the user reads it.
  final String label;

  /// The bucket a thread lands in when it is created, and the fallback for a
  /// name the app does not know.
  static const ThreadBucket fallback = ThreadBucket.emBreve;

  /// The bucket [wire] names, or [fallback].
  static ThreadBucket fromWire(String? wire) {
    return ThreadBucket.values.firstWhere(
      (bucket) => bucket.wire == wire,
      orElse: () => fallback,
    );
  }
}

/// {@template thread}
/// A conversation, with every message it holds.
/// {@endtemplate}
class Thread extends Equatable {
  /// {@macro thread}
  const Thread({
    required this.slug,
    required this.title,
    required this.messages,
    required this.solved,
    required this.bucket,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [Thread] from the API's JSON.
  factory Thread.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? <dynamic>[];

    return Thread(
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      messages: rawMessages
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      solved: json['solved'] as bool? ?? false,
      bucket: ThreadBucket.fromWire(json['bucket'] as String?),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  /// The folder name on disk, and the id the API addresses it by.
  final String slug;

  /// A one-line name, taken from the thread's first message.
  final String title;

  /// Every message, oldest first.
  final List<ChatMessage> messages;

  /// Whether the user has marked this thread closed.
  final bool solved;

  /// Which of the home screen's lists it sits in.
  final ThreadBucket bucket;

  /// When the thread's first message was written.
  final DateTime createdAt;

  /// When the thread's last message was written.
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    slug,
    title,
    messages,
    solved,
    bucket,
    createdAt,
    updatedAt,
  ];
}

/// {@template thread_summary}
/// A thread without its messages, for the home screen's list.
/// {@endtemplate}
class ThreadSummary extends Equatable {
  /// {@macro thread_summary}
  const ThreadSummary({
    required this.slug,
    required this.title,
    required this.preview,
    required this.messageCount,
    required this.solved,
    required this.bucket,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [ThreadSummary] from the API's JSON.
  factory ThreadSummary.fromJson(Map<String, dynamic> json) {
    return ThreadSummary(
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? 0,
      solved: json['solved'] as bool? ?? false,
      bucket: ThreadBucket.fromWire(json['bucket'] as String?),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  /// The folder name on disk, and the id the API addresses it by.
  final String slug;

  /// A one-line name, taken from the thread's first message.
  final String title;

  /// The last message's text, on one line.
  final String preview;

  /// How many messages the thread holds.
  final int messageCount;

  /// Whether the thread is solved.
  ///
  /// A solved thread leaves the timeline altogether. It is still there, under
  /// the concluded items in the menu, and coming back out of that list is the
  /// only way it returns to a bucket.
  final bool solved;

  /// Which of the home screen's lists it sits in.
  final ThreadBucket bucket;

  /// When the thread's first message was written.
  final DateTime createdAt;

  /// When the thread's last message was written.
  final DateTime updatedAt;

  /// Returns a copy with the given fields replaced.
  ThreadSummary copyWith({ThreadBucket? bucket, bool? solved}) {
    return ThreadSummary(
      slug: slug,
      title: title,
      preview: preview,
      messageCount: messageCount,
      solved: solved ?? this.solved,
      bucket: bucket ?? this.bucket,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    slug,
    title,
    preview,
    messageCount,
    solved,
    bucket,
    createdAt,
    updatedAt,
  ];
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();
}
