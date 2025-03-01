import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/home/header/progress_bar/bloc/progress_bar_cubit.dart';

void main() {
  group('ProgressBarState', () {
    final testTime = DateTime(2025, 3, 1, 14, 39);

    test('progressPercentage calculates correctly', () {
      final state = ProgressBarState(currentTime: testTime);
      final percentage = state.progressPercentage();
      expect(percentage, greaterThan(0));
      expect(percentage, lessThan(1));
    });

    test('formattedInitialTime returns correct format', () {
      final state = ProgressBarState(currentTime: testTime);
      expect(state.formattedInitialTime, equals('☀️07:00'));
    });

    test('formattedFinalTime returns correct format', () {
      final state = ProgressBarState(currentTime: testTime);
      expect(state.formattedFinalTime, equals('22:00 😴'));
    });

    test('gradient has correct colors and stops', () {
      final state = ProgressBarState(currentTime: testTime);
      expect(state.gradient.colors.length, equals(5));
      expect(state.gradient.stops, equals([0, 5 / 15, 10 / 15, 12 / 15, 1]));
    });
  });
}
