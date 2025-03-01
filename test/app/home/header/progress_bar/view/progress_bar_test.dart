import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/home/header/progress_bar/view/progress_bar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timer/timer.dart';
import 'package:provider/provider.dart';

class MockTimerRepository extends Mock implements TimerRepository {}

void main() {
  group('ProgressBar', () {
    late TimerRepository timerRepository;
    final testTime = DateTime(2025, 3, 1, 14, 39);

    setUp(() {
      timerRepository = MockTimerRepository();
      when(() => timerRepository.currentTime).thenReturn(testTime);
      when(() => timerRepository.currentTimeStream)
          .thenAnswer((_) => Stream.value(testTime));
    });

    testWidgets('renders progress bar with time labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<TimerRepository>.value(
            value: timerRepository,
            child: const ProgressBar(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('☀️07:00'), findsOneWidget);
      expect(find.text('22:00 😴'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders ProgressBarContent with correct values', (tester) async {
      const progressPercentage = 0.5;
      const gradient = LinearGradient(colors: [Colors.blue, Colors.red]);

      await tester.pumpWidget(
        MaterialApp(
          home: ProgressBarContent(
            progressPercentage: progressPercentage,
            gradient: gradient,
            initialValue: '☀️07:00',
            finalValue: '22:00 😴',
          ),
        ),
      );

      expect(find.text('☀️07:00'), findsOneWidget);
      expect(find.text('22:00 😴'), findsOneWidget);
    });
  });
}
