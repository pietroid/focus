import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/home/header/view/home_header.dart';
import 'package:focus/app/home/header/clock/view/clock.dart';
import 'package:focus/app/home/header/progress_bar/view/progress_bar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timer/timer.dart';
import 'package:provider/provider.dart';

class MockTimerRepository extends Mock implements TimerRepository {}

void main() {
  group('HomeHeader', () {
    late TimerRepository timerRepository;
    final testTime = DateTime(2025, 3, 1, 14, 42);

    setUp(() {
      timerRepository = MockTimerRepository();
      when(() => timerRepository.currentTime).thenReturn(testTime);
      when(() => timerRepository.currentTimeStream)
          .thenAnswer((_) => Stream.value(testTime));
    });

    testWidgets('renders all components', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<TimerRepository>.value(
            value: timerRepository,
            child: const HomeHeader(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(Clock), findsOneWidget);
      expect(find.byType(ProgressBar), findsOneWidget);
    });
  });
}
