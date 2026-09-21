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

/// {@template timeline_event}
/// One card on the timeline: a block of time on the calendar.
///
/// Every card is an event, because every hour of the day is one. Some have a
/// conversation behind them and most do not, which is what [threadSlug] says.
/// The pairing is kept on the event itself, so nothing in the app or in a
/// thread file has to remember an hour.
/// {@endtemplate}
class TimelineEvent extends Equatable {
  /// {@macro timeline_event}
  const TimelineEvent({
    required this.id,
    required this.title,
    required this.section,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.fixed = false,
    this.managed = true,
    this.threadSlug,
    this.preview = '',
    this.messageCount = 0,
  });

  /// Creates a [TimelineEvent] from the API's JSON.
  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      section: TimelineSection.fromWire(json['section'] as String?),
      startTime: _date(json['startTime']),
      endTime: _date(json['endTime']),
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      fixed: json['fixed'] as bool? ?? false,
      managed: json['managed'] as bool? ?? true,
      threadSlug: json['threadSlug'] as String?,
      preview: json['preview'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? 0,
    );
  }

  /// The Google event id, which is the only name it answers to.
  final String id;

  /// What the block is called.
  final String title;

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

  /// Whether Focus booked it.
  ///
  /// A block that is not managed is a meeting that reached the calendar some
  /// other way. It is drawn, because the hour is not free, and it cannot be
  /// dragged or finished, because neither is the app's to do with it.
  final bool managed;

  /// The conversation about this block, when there is one.
  final String? threadSlug;

  /// The last thing said in that conversation, on one line.
  final String preview;

  /// How many messages it holds.
  final int messageCount;

  /// Whether the card can be dragged or finished.
  bool get isInteractive => managed;

  @override
  List<Object?> get props => [
    id,
    title,
    section,
    startTime,
    endTime,
    durationMinutes,
    fixed,
    managed,
    threadSlug,
    preview,
    messageCount,
  ];
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();
}

/// {@template timeline_outcome}
/// What a move produced: the timeline, and the question still in the way.
///
/// A guard means nothing was applied. The cards that come back are the ones
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
          .map((c) => TimelineEvent.fromJson(c as Map<String, dynamic>))
          .toList(),
      guard: rawGuard == null ? null : A2uiComponent.fromJson(rawGuard),
    );
  }

  /// Every card the timeline should draw.
  final List<TimelineEvent> cards;

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
