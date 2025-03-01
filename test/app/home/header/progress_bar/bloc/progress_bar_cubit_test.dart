import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/home/header/progress_bar/bloc/progress_bar_cubit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timer/timer.dart';
import 'package:rxdart/subjects.dart';

class MockTimerRepository extends Mock implements TimerRepository {}

void main() {
  group('ProgressBarCubit', () {
    late TimerRepository timerRepository;
    final testTime = DateTime(2025, 3, 1, 14, 39);

    setUp(() {
      timerRepository = MockTimerRepository();
      when(() => timerRepository.currentTime).thenReturn(testTime);
      when(() => timerRepository.currentTimeStream)
          .thenAnswer((_) => BehaviorSubject.seeded(testTime));
    });

    test('initial state has current time from repository', () {
      final cubit = ProgressBarCubit(timerRepository: timerRepository);
      expect(cubit.state.currentTime, equals(testTime));
    });

    test('emits new state when time changes', () async {
      final newTime = testTime.add(const Duration(hours: 1));
      final timeController = BehaviorSubject<DateTime>.seeded(testTime);
      when(() => timerRepository.currentTimeStream)
          .thenAnswer((_) => timeController.stream);

      final cubit = ProgressBarCubit(timerRepository: timerRepository);
      await Future.delayed(Duration.zero);
      timeController.add(newTime);

      expect(
        cubit.stream,
        emits(
          isA<ProgressBarState>().having(
            (state) => state.currentTime,
            'currentTime',
            equals(newTime),
          ),
        ),
      );
    });
  });
}
