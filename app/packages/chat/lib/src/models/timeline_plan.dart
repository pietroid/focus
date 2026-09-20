import 'package:chat/src/models/thread.dart';

/// Where something new would land, worked out on the phone.
///
/// The server is what actually decides, and this is deliberately the same
/// arithmetic rather than a request: the creation sheet has to say what time
/// it is proposing while the user is still typing, and a round trip per
/// keystroke to answer a question the phone already has the cards for would
/// be a spinner where a number should be.
///
/// It can be wrong, in one way only: something the user booked on another
/// device since the last load. The next list puts it right.
abstract final class TimelinePlan {
  /// The first hour of the working day.
  static const startHour = 7;

  /// The hour the working day ends.
  static const endHour = 22;

  /// The breathing room left between two blocks.
  static const gap = Duration(minutes: 5);

  /// The first slot of [duration] that fits from [now], moving nothing.
  ///
  /// Walks the day forward: each card it runs into pushes the candidate to
  /// the end of that card plus the gap, and a candidate that spills past the
  /// end of the day starts again at the top of the next one.
  static DateTime nextFreeStart(
    List<ThreadSummary> cards,
    Duration duration, {
    DateTime? now,
  }) {
    final booked = [...cards]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    var start = _earliest(now ?? DateTime.now());

    // One pass per block it steps over, plus one per day it spills out of.
    for (var attempt = 0; attempt < 500; attempt++) {
      final end = start.add(duration);
      final dayEnd = DateTime(start.year, start.month, start.day, endHour);

      if (end.isAfter(dayEnd)) {
        start = DateTime(start.year, start.month, start.day + 1, startHour);
        continue;
      }

      final hit = booked
          .where((card) => start.isBefore(card.endTime) &&
              card.startTime.isBefore(end))
          .firstOrNull;
      if (hit == null) return start;

      start = _roundToFive(hit.endTime.add(gap));
    }

    return start;
  }

  /// The earliest [at] could be, given the day has hours.
  static DateTime _earliest(DateTime at) {
    final dayStart = DateTime(at.year, at.month, at.day, startHour);
    final dayEnd = DateTime(at.year, at.month, at.day, endHour);

    if (at.isBefore(dayStart)) return dayStart;
    if (at.isBefore(dayEnd)) {
      return DateTime(at.year, at.month, at.day, at.hour, at.minute);
    }

    return DateTime(at.year, at.month, at.day + 1, startHour);
  }

  /// The next minute divisible by five, so the day reads tidily.
  static DateTime _roundToFive(DateTime at) {
    final rest = at.minute % 5;
    final rounded = rest == 0 ? at : at.add(Duration(minutes: 5 - rest));

    return DateTime(
      rounded.year,
      rounded.month,
      rounded.day,
      rounded.hour,
      rounded.minute,
    );
  }
}
