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
    'the break between two blocks is a card, not an empty Agora',
    (
      tester,
    ) async {
      await pump(tester, [later]);

      expect(find.text('Agora'), findsOneWidget);
      expect(find.byType(RestTile), findsOneWidget);
      // What comes next is the card right below; the break does not repeat it.
      expect(find.textContaining('Depois:'), findsNothing);
      // The break is only drawn inside the working day.
    },
    skip: now.hour < 7 || now.hour >= 22,
  );
}
