import 'package:chat/src/models/chat_message.dart';
import 'package:equatable/equatable.dart';

/// Which of the home screen's three lists a card sits in.
///
/// For an untimed thread the bucket is the user's own judgement: it starts in
/// [ThreadBucket.emBreve] and moves only because someone dragged it. Anything
/// with a time on it is filed by the clock instead, on the server, which is
/// also where every rule about that lives.
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

/// Where a card came from.
///
/// A [CardKind.calendar] card is a Google event with no conversation behind
/// it. It is drawn so the screen says the same thing the calendar does, and
/// it cannot be opened, dragged or solved, because there is nothing here to
/// open and nowhere else for it to go.
enum CardKind {
  /// A thread: something written in Focus.
  thread('thread'),

  /// An event read off the calendar.
  calendar('calendar');

  const CardKind(this.wire);

  /// The name the API uses.
  final String wire;

  /// The kind [wire] names, defaulting to a thread.
  static CardKind fromWire(String? wire) {
    return CardKind.values.firstWhere(
      (kind) => kind.wire == wire,
      orElse: () => CardKind.thread,
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
    this.kind = CardKind.thread,
    this.startTime,
    this.endTime,
    this.durationMinutes,
  });

  /// Creates a [ThreadSummary] from the API's JSON.
  factory ThreadSummary.fromJson(Map<String, dynamic> json) {
    return ThreadSummary(
      kind: CardKind.fromWire(json['kind'] as String?),
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? 0,
      solved: json['solved'] as bool? ?? false,
      bucket: ThreadBucket.fromWire(json['bucket'] as String?),
      startTime: _optionalDate(json['startTime']),
      endTime: _optionalDate(json['endTime']),
      durationMinutes: json['durationMinutes'] as int?,
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  /// Whether there is a thread behind this card.
  final CardKind kind;

  /// The folder name on disk, or `gcal-<eventId>` for a calendar card.
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

  /// When it starts, when it has a time at all.
  final DateTime? startTime;

  /// When it ends.
  final DateTime? endTime;

  /// How long it takes, when anyone has said.
  final int? durationMinutes;

  /// When the thread's first message was written.
  final DateTime createdAt;

  /// When the thread's last message was written.
  final DateTime updatedAt;

  /// Whether the clock, rather than the user, decides where this card sits.
  bool get isTimed => startTime != null && endTime != null;

  /// Whether the card can be dragged, opened or solved.
  bool get isInteractive => kind == CardKind.thread;

  /// Returns a copy with the given fields replaced.
  ThreadSummary copyWith({ThreadBucket? bucket, bool? solved}) {
    return ThreadSummary(
      kind: kind,
      slug: slug,
      title: title,
      preview: preview,
      messageCount: messageCount,
      solved: solved ?? this.solved,
      bucket: bucket ?? this.bucket,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    kind,
    slug,
    title,
    preview,
    messageCount,
    solved,
    bucket,
    startTime,
    endTime,
    durationMinutes,
    createdAt,
    updatedAt,
  ];
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();
}

/// A date the API may simply not have, which is different from one it got
/// wrong: an untimed card has no start, and inventing "now" for it would put
/// it on the clock.
DateTime? _optionalDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// {@template timeline_outcome}
/// What a move produced: the timeline, and the question still in the way.
///
/// A guard means nothing was applied. The lists that come back are the ones
/// that were already on screen, and they become real only once the guard has
/// been answered or dropped.
/// {@endtemplate}
class TimelineOutcome extends Equatable {
  /// {@macro timeline_outcome}
  const TimelineOutcome({required this.cards, this.guard});

  /// Creates a [TimelineOutcome] from the API's JSON.
  factory TimelineOutcome.fromJson(Map<String, dynamic> json) {
    final rawGuard = json['guard'] as Map<String, dynamic>?;

    return TimelineOutcome(
      cards: (json['cards'] as List<dynamic>? ?? <dynamic>[])
          .map((c) => ThreadSummary.fromJson(c as Map<String, dynamic>))
          .toList(),
      guard: rawGuard == null ? null : A2uiComponent.fromJson(rawGuard),
    );
  }

  /// Every card the timeline should draw.
  final List<ThreadSummary> cards;

  /// The question to put to the user, when the move raised one.
  final A2uiComponent? guard;

  @override
  List<Object?> get props => [cards, guard];
}
