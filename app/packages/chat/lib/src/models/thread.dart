import 'package:chat/src/models/chat_message.dart';
import 'package:equatable/equatable.dart';

/// Which stretch of the clock a card falls in.
///
/// A section is not a place anything is put. It is what the card's own hour
/// works out to when the list is read, on the server, so a heading is always
/// literally true of everything under it. There are three today and they are
/// meant to become one per day.
enum TimelineSection {
  /// Running, or overdue and still owed.
  agora('agora', 'Agora'),

  /// Later today.
  hoje('hoje', 'Ainda hoje'),

  /// The next day.
  amanha('amanha', 'Amanhã');

  const TimelineSection(this.wire, this.label);

  /// The name the API uses.
  final String wire;

  /// The section header, as the user reads it.
  final String label;

  /// The section [wire] names, defaulting to today.
  static TimelineSection fromWire(String? wire) {
    return TimelineSection.values.firstWhere(
      (section) => section.wire == wire,
      orElse: () => TimelineSection.hoje,
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
    createdAt,
    updatedAt,
  ];
}

/// {@template thread_summary}
/// One card on the timeline: a thread without its messages, or an event.
///
/// Everything on the timeline has an hour. A thread that has not been given
/// one is not a card at all, so there are no optional times here and no card
/// that reads as half-planned.
/// {@endtemplate}
class ThreadSummary extends Equatable {
  /// {@macro thread_summary}
  const ThreadSummary({
    required this.slug,
    required this.title,
    required this.preview,
    required this.messageCount,
    required this.solved,
    required this.section,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.kind = CardKind.thread,
    this.fixed = false,
  });

  /// Creates a [ThreadSummary] from the API's JSON.
  factory ThreadSummary.fromJson(Map<String, dynamic> json) {
    final start = _date(json['startTime']);

    return ThreadSummary(
      kind: CardKind.fromWire(json['kind'] as String?),
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? 0,
      solved: json['solved'] as bool? ?? false,
      section: TimelineSection.fromWire(json['section'] as String?),
      startTime: start,
      endTime: _date(json['endTime']),
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      fixed: json['fixed'] as bool? ?? false,
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
  final bool solved;

  /// The stretch of clock it falls in.
  final TimelineSection section;

  /// When it starts.
  final DateTime startTime;

  /// When it ends.
  final DateTime endTime;

  /// How long it takes.
  final int durationMinutes;

  /// Whether the hour is the point of it, and so cannot be rearranged.
  final bool fixed;

  /// When the thread's first message was written.
  final DateTime createdAt;

  /// When the thread's last message was written.
  final DateTime updatedAt;

  /// Whether the card can be dragged, opened or solved.
  bool get isInteractive => kind == CardKind.thread;

  /// Returns a copy with the given fields replaced.
  ThreadSummary copyWith({bool? solved}) {
    return ThreadSummary(
      kind: kind,
      slug: slug,
      title: title,
      preview: preview,
      messageCount: messageCount,
      solved: solved ?? this.solved,
      section: section,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      fixed: fixed,
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
    section,
    startTime,
    endTime,
    durationMinutes,
    fixed,
    createdAt,
    updatedAt,
  ];
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();
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

/// {@template sync_outcome}
/// How the calendar catch-up went.
///
/// [ok] is the answer nearly every time, and the user never learns that any
/// of it happened. When it is false the day on screen is still right: it is
/// the copy on Google that fell behind, and [guard] is the popup that says so
/// and offers to push it again.
/// {@endtemplate}
class SyncOutcome extends Equatable {
  /// {@macro sync_outcome}
  const SyncOutcome({required this.ok, this.guard});

  /// Creates a [SyncOutcome] from the API's JSON.
  factory SyncOutcome.fromJson(Map<String, dynamic> json) {
    final rawGuard = json['guard'] as Map<String, dynamic>?;

    return SyncOutcome(
      ok: json['ok'] as bool? ?? true,
      guard: rawGuard == null ? null : A2uiComponent.fromJson(rawGuard),
    );
  }

  /// Whether everything reached the calendar.
  final bool ok;

  /// What to put on screen when it did not.
  final A2uiComponent? guard;

  @override
  List<Object?> get props => [ok, guard];
}
