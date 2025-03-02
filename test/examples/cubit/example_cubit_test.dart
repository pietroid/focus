import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/examples/cubit/example_cubit.dart';

void main() {
  group('ExampleCubit', () {
    test('initial state is ExampleInitial', () {
      expect(
        ExampleCubit().state,
        isA<ExampleInitial>(),
      );
    });

    blocTest<ExampleCubit, ExampleState>(
      'emits [ExampleStateA] when methodOne is called',
      build: ExampleCubit.new,
      act: (cubit) => cubit.methodOne(),
      expect: () => [isA<ExampleStateA>()],
    );

    blocTest<ExampleCubit, ExampleState>(
      'emits [ExampleStateB] when methodTwo is called',
      build: ExampleCubit.new,
      act: (cubit) => cubit.methodTwo(),
      expect: () => [isA<ExampleStateB>()],
    );

    blocTest<ExampleCubit, ExampleState>(
      'handles multiple method calls in sequence',
      build: ExampleCubit.new,
      act: (cubit) {
        cubit.methodOne();
        cubit.methodTwo();
      },
      expect: () => [
        isA<ExampleStateA>(),
        isA<ExampleStateB>(),
      ],
    );
  });
}
