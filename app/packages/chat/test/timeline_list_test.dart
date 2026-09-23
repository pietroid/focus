import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTimelineBloc extends MockBloc<TimelineBlocEvent, TimelineState>
    implements TimelineBloc {}

/// Lets a sheet open or close. Not `pumpAndSettle`: the running card's light
/// goes round forever, so the screen never settles.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() => registerFallbackValue(const TimelineRequested()));

  final now = DateTime.now();
  final running = TimelineEvent(
    id: 'a',
    title: 'Escrever',
    section: TimelineSection.agora,
    startTime: now.subtract(const Duration(minutes: 10)),
    endTime: now.add(const Duration(minutes: 20)),
    durationMinutes: 30,
  );
  final later = TimelineEvent(
    id: 'b',
    title: 'Depois',
    section: TimelineSection.hoje,
    startTime: now.add(const Duration(minutes: 25)),
    endTime: now.add(const Duration(minutes: 55)),
    durationMinutes: 30,
  );

  Future<(TimelineBloc, List<TimelineEvent>)> pump(
    WidgetTester tester,
    List<TimelineEvent> cards,
  ) async {
    final bloc = _MockTimelineBloc();
    when(() => bloc.state).thenReturn(
      TimelineState(status: TimelineStatus.success, cards: cards),
    );
    final tapped = <TimelineEvent>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: BlocProvider<TimelineBloc>.value(
            value: bloc,
            child: TimelineList(onCardTap: tapped.add),
          ),
        ),
      ),
    );
    await tester.pump();

    return (bloc as TimelineBloc, tapped);
  }

  testWidgets('a button on the running card is not a tap on the card', (
    tester,
  ) async {
    final (bloc, tapped) = await pump(tester, [running, later]);

    await tester.tap(find.byIcon(AppIcons.pause.iconData!));
    await tester.pump(const Duration(milliseconds: 400));

    verify(() => bloc.add(const EventPauseToggled('a'))).called(1);
    expect(tapped, isEmpty);

    await tester.tap(find.text('+15'));
    await settle(tester);
    expect(tapped, isEmpty);
    // Changing the length moves the rest of the day, so it asks first.
    verifyNever(() => bloc.add(const EventExtended('a')));
    expect(find.text('Mais 15 minutos?'), findsOneWidget);

    await tester.tap(find.text('Adicionar'));
    await settle(tester);
    verify(() => bloc.add(const EventExtended('a'))).called(1);
  });

  testWidgets('takes fifteen minutes off only once it is confirmed', (
    tester,
  ) async {
    final (bloc, _) = await pump(tester, [running, later]);

    await tester.tap(find.text('−15'));
    await settle(tester);
    expect(find.text('Menos 15 minutos?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    verifyNever(() => bloc.add(any()));

    await tester.tap(find.text('−15'));
    await settle(tester);
    await tester.tap(find.text('Tirar'));
    await settle(tester);
    verify(() => bloc.add(const EventExtended('a', minutes: -15))).called(1);
  });

  testWidgets('a tap on the card itself still opens it', (tester) async {
    final (_, tapped) = await pump(tester, [running, later]);

    await tester.tap(find.text('Depois'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tapped.map((card) => card.id), ['b']);
  });

  testWidgets(
    'the break between two blocks is a free stretch, not an empty Agora',
    (tester) async {
      await pump(tester, [later]);

      expect(find.text('Agora'), findsOneWidget);
      // Now until the next block, after it until ten, and all of tomorrow.
      expect(find.byType(FreeTile), findsNWidgets(3));
      expect(find.text('Nada programado'), findsNWidgets(3));
      // Only the one happening now is the break, and says so.
      final breakLines = FreeTile.messages.where(
        (line) => find.text(line).evaluate().isNotEmpty,
      );
      expect(breakLines, hasLength(1));
    },
    // The stretch from now is only drawn inside the working day.
    skip: now.hour < 7 || now.hour >= 21,
  );

  testWidgets('a card says when it starts, and not when it ends', (
    tester,
  ) async {
    await pump(tester, [running, later]);

    String hhmm(DateTime at) =>
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';

    final tile = find.widgetWithText(EventTile, 'Depois');
    expect(
      find.descendant(of: tile, matching: find.text(hhmm(later.startTime))),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tile,
        matching: find.textContaining(hhmm(later.endTime)),
      ),
      findsNothing,
    );
  });

  testWidgets('a block whose hour came asks to be begun', (tester) async {
    final waiting = TimelineEvent(
      id: 'w',
      title: 'Esperando',
      section: TimelineSection.agora,
      startTime: now,
      endTime: now.add(const Duration(minutes: 30)),
      durationMinutes: 30,
      awaitingStart: true,
    );
    final (bloc, tapped) = await pump(tester, [waiting]);

    expect(find.text('Hora de começar'), findsOneWidget);
    // Nothing is running yet, so there is nothing to pause.
    expect(find.byIcon(AppIcons.pause.iconData!), findsNothing);

    await tester.tap(find.byIcon(AppIcons.play.iconData!));
    await tester.pump(const Duration(milliseconds: 400));
    verify(() => bloc.add(const EventStarted('w'))).called(1);

    await tester.tap(find.text('15 min'));
    await tester.pump(const Duration(milliseconds: 400));
    verify(() => bloc.add(const EventSnoozed('w'))).called(1);
    expect(tapped, isEmpty);
  });

  testWidgets('a routine is drawn with its mark and cannot be opened', (
    tester,
  ) async {
    final lunch = TimelineEvent(
      id: 'lunch',
      title: 'Almoço',
      section: TimelineSection.hoje,
      startTime: now.add(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 2)),
      durationMinutes: 60,
      fixed: true,
      routine: 'daily',
    );
    final (_, tapped) = await pump(tester, [lunch]);

    expect(find.byIcon(AppIcons.repeat.iconData!), findsOneWidget);

    await tester.tap(find.text('Almoço'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tapped, isEmpty);
  });

  testWidgets(
    'a card too long for the gap it is dropped in asks to be cut to fit',
    (tester) async {
      final first = TimelineEvent(
        id: 'x',
        title: 'Primeiro',
        section: TimelineSection.hoje,
        startTime: now.add(const Duration(minutes: 20)),
        endTime: now.add(const Duration(minutes: 50)),
        durationMinutes: 30,
      );
      final meeting = TimelineEvent(
        id: 'f',
        title: 'Reunião',
        section: TimelineSection.hoje,
        startTime: now.add(const Duration(minutes: 80)),
        endTime: now.add(const Duration(minutes: 110)),
        durationMinutes: 30,
        fixed: true,
      );
      final long = TimelineEvent(
        id: 'long',
        title: 'Longo',
        section: TimelineSection.hoje,
        startTime: now.add(const Duration(minutes: 115)),
        endTime: now.add(const Duration(minutes: 175)),
        durationMinutes: 60,
      );
      final (bloc, _) = await pump(tester, [first, meeting, long]);

      final gap = find.byWidgetPredicate(
        (widget) => widget is FreeTile && widget.slot.start == first.endTime,
      );
      expect(gap, findsOneWidget);

      final from = tester.getCenter(find.text('Longo'));
      final target = tester.getCenter(gap);
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 350));
      for (var step = 1; step <= 8; step++) {
        await gesture.moveTo(Offset.lerp(from, target, step / 8)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settle(tester);

      // Twenty-five minutes of room: the gap less the pause after "Primeiro".
      expect(find.text('Não cabe inteiro aqui'), findsOneWidget);
      verifyNever(() => bloc.add(any(that: isA<EventMoved>())));

      await tester.tap(find.text('Ajustar para 25 min'));
      await settle(tester);

      verify(
        () => bloc.add(
          EventMoved(
            id: 'long',
            index: 1,
            after: first.endTime.add(const Duration(minutes: 5)),
            minutes: 25,
          ),
        ),
      ).called(1);
    },
    skip: now.hour < 7 || now.hour >= 18,
  );
}
