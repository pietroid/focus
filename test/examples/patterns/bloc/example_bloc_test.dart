import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/examples/patterns/bloc/example_bloc.dart';

void main() {
  group('ExampleBloc', () {
    test('initial state is ExampleInitial', () {
      expect(
        ExampleBloc().state,
        isA<ExampleInitial>(),
      );
    });

    blocTest<ExampleBloc, ExampleState>(
      'emits [ExampleStateA] when ExampleEventOne is added',
      build: ExampleBloc.new,
      act: (bloc) => bloc.add(ExampleEventOne()),
      expect: () => [isA<ExampleStateA>()],
    );

    blocTest<ExampleBloc, ExampleState>(
      'emits [ExampleStateB] when ExampleEventTwo is added',
      build: ExampleBloc.new,
      act: (bloc) => bloc.add(ExampleEventTwo()),
      expect: () => [isA<ExampleStateB>()],
    );

    blocTest<ExampleBloc, ExampleState>(
      'handles multiple events in sequence',
      build: ExampleBloc.new,
      act: (bloc) => bloc
        ..add(ExampleEventOne())
        ..add(ExampleEventTwo()),
      expect: () => [
        isA<ExampleStateA>(),
        isA<ExampleStateB>(),
      ],
    );
  });
}
