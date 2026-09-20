import 'package:bloc_test/bloc_test.dart';
import 'package:chat/chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

ThreadSummary _thread(
  String slug,
  ThreadBucket bucket, {
  CardKind kind = CardKind.thread,
}) {
  return ThreadSummary(
    kind: kind,
    slug: slug,
    title: slug,
    preview: '',
    messageCount: 1,
    solved: false,
    bucket: bucket,
    createdAt: DateTime(2026, 8, 27, 9),
    updatedAt: DateTime(2026, 8, 27, 9),
  );
}

/// A guard, as the server would send one.
const _guard = A2uiComponent(
  component: 'Column',
  children: [
    A2uiComponent(component: 'Text', properties: {'text': 'Quanto tempo?'}),
  ],
);

/// The placement, flattened back into the list a server would return.
///
/// A thread the app left out of the placement is one it has already solved,
/// and the server sends those back too: they are still the user's, they are
/// just not on the timeline. Leaving them out here would have the double
/// deleting threads the real server keeps.
List<ThreadSummary> _applied(Map<ThreadBucket, List<String>> buckets) {
  final placed = buckets.values.expand((slugs) => slugs).toSet();

  return [
    for (final entry in buckets.entries)
      for (final slug in entry.value)
        _threads.firstWhere((t) => t.slug == slug).copyWith(bucket: entry.key),
    for (final thread in _threads)
      if (!placed.contains(thread.slug)) thread.copyWith(solved: true),
  ];
}

/// The list as it comes back from the server: one flat list, bucket order
/// first and place within the bucket second.
final _threads = <ThreadSummary>[
  _thread('a', ThreadBucket.agora),
  _thread('b', ThreadBucket.emBreve),
  _thread('c', ThreadBucket.emBreve),
  _thread('d', ThreadBucket.depois),
];

void main() {
  late ChatRepository repository;

  setUp(() {
    repository = _MockChatRepository();
    when(repository.fetchThreads).thenAnswer((_) async => _threads);
    // The server is the one that says what the lists look like afterwards, so
    // the double answers with the placement it was given rather than with the
    // list it started from.
    when(() => repository.savePlacements(any())).thenAnswer(
      (invocation) async => TimelineOutcome(
        cards: _applied(
          invocation.positionalArguments.first
              as Map<ThreadBucket, List<String>>,
        ),
      ),
    );
    when(
      () => repository.setSolved(any(), solved: any(named: 'solved')),
    ).thenAnswer((_) async => []);
  });

  ThreadsBloc build() => ThreadsBloc(chatRepository: repository);

  /// The bucket each thread is in, in the order they are drawn.
  List<String> placement(ThreadsState state) {
    return [
      for (final thread in state.threads)
        '${thread.slug}:${thread.bucket.wire}',
    ];
  }

  group('ThreadsBloc', () {
    blocTest<ThreadsBloc, ThreadsState>(
      'loads the list',
      build: build,
      act: (bloc) => bloc.add(const ThreadsRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.inBucket(ThreadBucket.emBreve), hasLength(2));
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'moves a thread into another list at the index it was dropped on',
      build: build,
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const ThreadMoved(
            slug: 'd',
            bucket: ThreadBucket.emBreve,
            index: 1,
          ),
        );
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(placement(bloc.state), [
          'a:agora',
          'b:em_breve',
          'd:em_breve',
          'c:em_breve',
        ]);
        verify(
          () => repository.savePlacements({
            ThreadBucket.agora: ['a'],
            ThreadBucket.emBreve: ['b', 'd', 'c'],
            ThreadBucket.depois: <String>[],
          }),
        ).called(1);
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'reorders inside one list',
      build: build,
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        // "c" dropped above "b": the view has already taken "c" out of the
        // list, so index 0 is the gap at the top.
        bloc.add(
          const ThreadMoved(
            slug: 'c',
            bucket: ThreadBucket.emBreve,
            index: 0,
          ),
        );
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(
          bloc.state.inBucket(ThreadBucket.emBreve).map((t) => t.slug),
          ['c', 'b'],
        );
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'ignores a move for a thread it does not have',
      build: build,
      act: (bloc) => bloc.add(
        const ThreadMoved(
          slug: 'gone',
          bucket: ThreadBucket.agora,
          index: 0,
        ),
      ),
      wait: const Duration(milliseconds: 10),
      verify: (_) => verifyNever(() => repository.savePlacements(any())),
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'leaves the drop on screen when the write fails',
      build: () {
        when(() => repository.savePlacements(any())).thenThrow(Exception('no'));
        return build();
      },
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const ThreadMoved(slug: 'd', bucket: ThreadBucket.agora, index: 0),
        );
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(
          bloc.state.inBucket(ThreadBucket.agora).map((t) => t.slug),
          ['d', 'a'],
        );
        expect(bloc.state.status, ThreadsStatus.failure);
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'takes a solved thread off the timeline and into the solved list',
      build: build,
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ThreadSolved('b', solved: true));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(
          bloc.state.inBucket(ThreadBucket.emBreve).map((t) => t.slug),
          ['c'],
        );
        expect(bloc.state.solved.map((t) => t.slug), ['b']);
        verify(() => repository.setSolved('b', solved: true)).called(1);
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'puts a recovered thread back in the list it left',
      build: build,
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ThreadSolved('b', solved: true));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ThreadSolved('b', solved: false));
      },
      wait: const Duration(milliseconds: 30),
      verify: (bloc) {
        expect(
          bloc.state.inBucket(ThreadBucket.emBreve).map((t) => t.slug),
          ['b', 'c'],
        );
        expect(bloc.state.solved, isEmpty);
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'puts the card back when solving it cannot be written',
      build: () {
        when(
          () => repository.setSolved(any(), solved: any(named: 'solved')),
        ).thenThrow(Exception('no'));
        return build();
      },
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ThreadSolved('b', solved: true));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.solved, isEmpty);
        expect(
          bloc.state.inBucket(ThreadBucket.emBreve).map((t) => t.slug),
          ['b', 'c'],
        );
        expect(bloc.state.status, ThreadsStatus.failure);
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'puts the card back and shows the question when a move raises a guard',
      build: () {
        when(() => repository.savePlacements(any())).thenAnswer(
          (_) async => TimelineOutcome(cards: _threads, guard: _guard),
        );
        return build();
      },
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const ThreadMoved(slug: 'd', bucket: ThreadBucket.agora, index: 0),
        );
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.guard, _guard);
        // The drag is undone while the question is up: nothing was applied on
        // the server, so nothing stays applied on screen.
        expect(
          bloc.state.inBucket(ThreadBucket.agora).map((t) => t.slug),
          ['a'],
        );
        expect(
          bloc.state.inBucket(ThreadBucket.depois).map((t) => t.slug),
          ['d'],
        );
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'draws the day the guard produced once it is answered',
      build: () {
        when(() => repository.applyTiming(any())).thenAnswer(
          (_) async => TimelineOutcome(
            cards: [
              _thread('d', ThreadBucket.agora),
              ..._threads.where((t) => t.slug != 'd'),
            ],
          ),
        );
        return build();
      },
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const GuardAnswered({'type': 'timing', 'slug': 'd'}));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.guard, isNull);
        expect(bloc.state.guardBusy, isFalse);
        expect(
          bloc.state.inBucket(ThreadBucket.agora).map((t) => t.slug),
          ['d', 'a'],
        );
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'keeps the sheet open when the guard has another question',
      build: () {
        when(() => repository.applyTiming(any())).thenAnswer(
          (_) async => TimelineOutcome(cards: _threads, guard: _guard),
        );
        return build();
      },
      act: (bloc) => bloc.add(const GuardAnswered({'type': 'timing'})),
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.guard, _guard);
        expect(bloc.state.guardBusy, isFalse);
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'drops a guard that is dismissed, and writes nothing',
      build: () {
        when(() => repository.savePlacements(any())).thenAnswer(
          (_) async => TimelineOutcome(cards: _threads, guard: _guard),
        );
        return build();
      },
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const ThreadMoved(slug: 'd', bucket: ThreadBucket.agora, index: 0),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const GuardDismissed());
      },
      wait: const Duration(milliseconds: 30),
      verify: (bloc) {
        expect(bloc.state.guard, isNull);
        verifyNever(() => repository.applyTiming(any()));
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'refuses to move a calendar card at all',
      build: () {
        when(repository.fetchThreads).thenAnswer(
          (_) async => [
            ..._threads,
            _thread('gcal-1', ThreadBucket.agora, kind: CardKind.calendar),
          ],
        );
        return build();
      },
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const ThreadMoved(
            slug: 'gcal-1',
            bucket: ThreadBucket.depois,
            index: 0,
          ),
        );
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        verifyNever(() => repository.savePlacements(any()));
        expect(
          bloc.state.inBucket(ThreadBucket.agora).map((t) => t.slug),
          ['a', 'gcal-1'],
        );
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'leaves a calendar card out of the placement a drag writes',
      build: () {
        when(repository.fetchThreads).thenAnswer(
          (_) async => [
            ..._threads,
            _thread('gcal-1', ThreadBucket.emBreve, kind: CardKind.calendar),
          ],
        );
        return build();
      },
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const ThreadMoved(slug: 'd', bucket: ThreadBucket.emBreve, index: 0),
        );
      },
      wait: const Duration(milliseconds: 20),
      verify: (_) {
        verify(
          () => repository.savePlacements({
            ThreadBucket.agora: ['a'],
            ThreadBucket.emBreve: ['d', 'b', 'c'],
            ThreadBucket.depois: <String>[],
          }),
        ).called(1);
      },
    );

    blocTest<ThreadsBloc, ThreadsState>(
      'leaves a solved thread out of the placement a later drag writes',
      build: build,
      act: (bloc) async {
        bloc.add(const ThreadsRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const ThreadSolved('b', solved: true));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(
          const ThreadMoved(slug: 'd', bucket: ThreadBucket.emBreve, index: 0),
        );
      },
      wait: const Duration(milliseconds: 30),
      verify: (bloc) {
        verify(
          () => repository.savePlacements({
            ThreadBucket.agora: ['a'],
            ThreadBucket.emBreve: ['d', 'c'],
            ThreadBucket.depois: <String>[],
          }),
        ).called(1);
        expect(bloc.state.solved.map((t) => t.slug), ['b']);
      },
    );
  });
}
