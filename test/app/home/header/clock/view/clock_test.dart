import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/home/header/clock/view/clock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timer/timer.dart';
import 'package:provider/provider.dart';

class MockTimerRepository extends Mock implements TimerRepository {}

void main() {
  group('Clock', () {
    late TimerRepository timerRepository;
    final testTime = DateTime(2025, 3, 1, 13, 36);

    setUp(() {
      timerRepository = MockTimerRepository();
      when(() => timerRepository.currentTime).thenReturn(testTime);
      when(() => timerRepository.currentTimeStream)
          .thenAnswer((_) => Stream.value(testTime));
    });

    testWidgets('renders current time and date', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<TimerRepository>.value(
            value: timerRepository,
            child: const Clock(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('13:36'), findsOneWidget);
      expect(find.text('Saturday, March 1'), findsOneWidget);
    });
  });
}
