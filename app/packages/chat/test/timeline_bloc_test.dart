import 'package:bloc_test/bloc_test.dart';
import 'package:chat/chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTimelineRepository extends Mock implements TimelineRepository {}

DateTime _at(int hour, {int minute = 0, int addDays = 0}) {
  return DateTime(2026, 8, 27 + addDays, hour, minute);
}

TimelineEvent _card(
  String id, {
  required TimelineSection section,
  required DateTime start,
  int minutes = 30,
  bool managed = true,
  bool fixed = false,
}) {
  return TimelineEvent(
    id: id,
    title: id,
    section: section,
    startTime: start,
    endTime: start.add(Duration(minutes: minutes)),
    durationMinutes: minutes,
    managed: managed,
    fixed: fixed,
  );
}

/// A guard, as the server would send one.
const _guard = A2uiComponent(
  component: 'Column',
  children: [
    A2uiComponent(component: 'Text', properties: {'text': 'Começar agora?'}),
  ],
);

/// The day as the server sends it: one flat list, in clock order.
final _cards = <TimelineEvent>[
  _card('a', section: TimelineSection.agora, start: _at(9)),
  _card('b', section: TimelineSection.hoje, start: _at(14)),
  _card('c', section: TimelineSection.hoje, start: _at(15)),
  _card('d', section: TimelineSection.amanha, start: _at(9, addDays: 1)),
];

/// The list with [id] lifted out and put back at [index].
///
/// The real server also rewrites every hour the move disturbed. The order is
/// the part the bloc is responsible for drawing, so that is the part the
/// double bothers to get right.
List<TimelineEvent> _moved(String id, int index) {
  final cards = [..._cards];
  final card = cards.removeAt(cards.indexWhere((c) => c.id == id));

  return cards..insert(index.clamp(0, cards.length), card);
}

void main() {
  late TimelineRepository repository;

  setUp(() {
    repository = _MockTimelineRepository();
    when(repository.fetchEvents).thenAnswer((_) async => _cards);
    when(() => repository.moveEvent(any(), any())).thenAnswer(
      (invocation) async => TimelineOutcome(
        cards: _moved(
          invocation.positionalArguments[0] as String,
          invocation.positionalArguments[1] as int,
        ),
      ),
    );
    when(() => repository.finishEvent(any())).thenAnswer((_) async => []);
    // The calendar keeps up unless a test says otherwise.
    when(
      repository.awaitSync,
    ).thenAnswer((_) async => const SyncOutcome(ok: true));
    when(
      repository.retrySync,
    ).thenAnswer((_) async => const SyncOutcome(ok: true));
  });

  TimelineBloc build() => TimelineBloc(repository: repository);

  List<String> order(TimelineState state) =>
      state.cards.map((card) => card.id).toList();

  group('TimelineBloc', () {
    blocTest<TimelineBloc, TimelineState>(
      'checks the calendar behind a drop, and says nothing when it kept up',
      build: build,
      act: (bloc) async {
        bloc.add(const TimelineRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const EventMoved(id: 'd', index: 0));
      },
      wait: const Duration(milliseconds: 30),
      verify: (bloc) {
        verify(repository.awaitSync).called(1);
        expect(bloc.state.guard, isNull);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'puts the popup up when the calendar fell behind',
      build: () {
        when(repository.awaitSync).thenAnswer(
          (_) async => const SyncOutcome(ok: false, guard: _guard),
        );
        return build();
      },
      act: (bloc) async {
        bloc.add(const TimelineRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const EventMoved(id: 'd', index: 0));
      },
      wait: const Duration(milliseconds: 30),
      verify: (bloc) {
        expect(bloc.state.guard, _guard);
        // The drop itself stands. Only the copy on Google fell behind.
        expect(order(bloc.state), ['d', 'a', 'b', 'c']);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'never covers an open question with the sync popup',
      build: () {
        when(() => repository.moveEvent(any(), any())).thenAnswer(
          (_) async => TimelineOutcome(cards: _cards, guard: _guard),
        );
        when(repository.awaitSync).thenAnswer(
          (_) async => const SyncOutcome(ok: false, guard: _guard),
        );
        return build();
      },
      act: (bloc) async {
        bloc.add(const TimelineRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const EventMoved(id: 'd', index: 0));
      },
      wait: const Duration(milliseconds: 30),
      verify: (_) {
        // A move that came back asking something never queued a check, so
        // the question the user is reading is the only thing on screen.
        verifyNever(repository.awaitSync);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'closes the popup when the retry gets the calendar back in step',
      build: build,
      act: (bloc) => bloc.add(const SyncRetried()),
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        verify(repository.retrySync).called(1);
        expect(bloc.state.guard, isNull);
        expect(bloc.state.guardBusy, isFalse);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'leaves the popup up when the retry fails too',
      build: () {
        when(repository.retrySync).thenAnswer(
          (_) async => const SyncOutcome(ok: false, guard: _guard),
        );
        return build();
      },
      act: (bloc) => bloc.add(const SyncRetried()),
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.guard, _guard);
        expect(bloc.state.guardBusy, isFalse);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'loads the day',
      build: build,
      act: (bloc) => bloc.add(const TimelineRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        expect(bloc.state.inSection(TimelineSection.hoje), hasLength(2));
        expect(bloc.state.status, TimelineStatus.success);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'draws the order the server sends back after a drop',
      build: build,
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
      ),
      act: (bloc) => bloc.add(const EventMoved(id: 'c', index: 0)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['c', 'a', 'b', 'd']);
        verify(() => repository.moveEvent('c', 0)).called(1);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'leaves the timeline alone and raises the guard the move came back with',
      build: () {
        when(() => repository.moveEvent(any(), any())).thenAnswer(
          (_) async => TimelineOutcome(cards: _cards, guard: _guard),
        );
        return build();
      },
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
      ),
      act: (bloc) => bloc.add(const EventMoved(id: 'c', index: 0)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        expect(bloc.state.guard, _guard);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'refuses to move a meeting Focus did not book',
      build: build,
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: [
          ..._cards,
          _card(
            'daily',
            section: TimelineSection.hoje,
            start: _at(11),
            managed: false,
          ),
        ],
      ),
      act: (bloc) => bloc.add(const EventMoved(id: 'daily', index: 0)),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(() => repository.moveEvent(any(), any()));
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'answers a guard and draws what came back',
      build: () {
        when(() => repository.applyTiming(any())).thenAnswer(
          (_) async => TimelineOutcome(cards: _moved('c', 0)),
        );
        return build();
      },
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
        guard: _guard,
      ),
      act: (bloc) => bloc.add(
        const GuardAnswered({'type': 'timing', 'eventId': 'c', 'index': 0}),
      ),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.guard, isNull);
        expect(order(bloc.state), ['c', 'a', 'b', 'd']);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'dropping a guard changes nothing',
      build: build,
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
        guard: _guard,
      ),
      act: (bloc) => bloc.add(const GuardDismissed()),
      verify: (bloc) {
        expect(bloc.state.guard, isNull);
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        verifyNever(() => repository.applyTiming(any()));
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'takes a finished card off the day before the write lands',
      build: build,
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
      ),
      act: (bloc) => bloc.add(const EventFinished('b')),
      verify: (bloc) {
        expect(order(bloc.state), isNot(contains('b')));
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'keeps the sentence the server refused in',
      build: () {
        when(
          () => repository.createEvent(
            title: any(named: 'title'),
            durationMinutes: any(named: 'durationMinutes'),
            fixed: any(named: 'fixed'),
            startTime: any(named: 'startTime'),
          ),
        ).thenThrow(const ChatFailure('A agenda não respondeu.'));
        return build();
      },
      act: (bloc) => bloc.add(
        const EventCreated(
          title: 'Revisar proposta',
          durationMinutes: 30,
          fixed: false,
        ),
      ),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.failure, 'A agenda não respondeu.');
        expect(bloc.state.status, TimelineStatus.failure);
        expect(bloc.state.cards, isEmpty);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'puts a finished card back when the write fails',
      build: () {
        when(() => repository.finishEvent(any())).thenThrow(Exception('nope'));
        return build();
      },
      seed: () => TimelineState(
        status: TimelineStatus.success,
        cards: _cards,
      ),
      act: (bloc) => bloc.add(const EventFinished('b')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        expect(bloc.state.status, TimelineStatus.failure);
      },
    );

    blocTest<TimelineBloc, TimelineState>(
      'writes something down and draws the day it came back in',
      build: () {
        when(
          () => repository.createEvent(
            title: any(named: 'title'),
            durationMinutes: any(named: 'durationMinutes'),
            fixed: any(named: 'fixed'),
            startTime: any(named: 'startTime'),
          ),
        ).thenAnswer((_) async => _cards);
        return build();
      },
      act: (bloc) => bloc.add(
        const EventCreated(
          title: 'Revisar proposta',
          durationMinutes: 30,
          fixed: false,
        ),
      ),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(order(bloc.state), ['a', 'b', 'c', 'd']);
        expect(bloc.state.status, TimelineStatus.success);
      },
    );
  });

  group('TimelinePlan', () {
    test('takes the hour asked for when the day is empty', () {
      final start = TimelinePlan.nextFreeStart(
        const [],
        const Duration(minutes: 30),
        now: _at(9, minute: 12),
      );

      expect(start, _at(9, minute: 12));
    });

    test('steps over what is already booked, keeping the gap', () {
      final start = TimelinePlan.nextFreeStart(
        [
          _card(
            'a',
            section: TimelineSection.agora,
            start: _at(9),
            minutes: 60,
          ),
        ],
        const Duration(minutes: 30),
        now: _at(9, minute: 30),
      );

      expect(start, _at(10, minute: 5));
    });

    test('fills a gap rather than queueing at the end', () {
      final start = TimelinePlan.nextFreeStart(
        [
          _card('a', section: TimelineSection.agora, start: _at(9)),
          _card('b', section: TimelineSection.hoje, start: _at(14)),
        ],
        const Duration(minutes: 30),
        now: _at(9),
      );

      expect(start, _at(9, minute: 35));
    });

    test('spills into the next day rather than past the end of this one', () {
      final start = TimelinePlan.nextFreeStart(
        const [],
        const Duration(minutes: 60),
        now: _at(21, minute: 30),
      );

      expect(start, _at(7, addDays: 1));
    });
  });
}
