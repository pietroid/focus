import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/home/header/clock/bloc/clock_cubit.dart';

void main() {
  group('ClockState', () {
    final testTime = DateTime(2025, 3, 1, 13, 36);

    test('formattedTime returns correct format', () {
      final state = ClockState(currentTime: testTime);
      expect(state.formattedTime(), equals('13:36'));
    });

    test('formattedDayOfTheWeek returns correct format', () {
      final state = ClockState(currentTime: testTime);
      expect(
        state.formattedDayOfTheWeek(),
        equals('Saturday, March 1'),
      );
    });
  });
}
