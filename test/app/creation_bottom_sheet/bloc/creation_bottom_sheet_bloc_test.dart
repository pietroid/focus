import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/creation_bottom_sheet/bloc/creation_bottom_sheet_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:things/things.dart';

class MockThingRepository extends Mock implements ThingRepository {}

class MockThing extends Mock implements Thing {}

void main() {
  group('CreationBottomSheetBloc', () {
    late ThingRepository thingRepository;
    late Thing existingThing;

    setUp(() {
      thingRepository = MockThingRepository();
      existingThing = MockThing();
      when(() => existingThing.content).thenReturn('Test Thing');
    });

    test('initial state is correct', () {
      final bloc = CreationBottomSheetBloc(
        thingRepository: thingRepository,
      );
      expect(bloc.state, equals(const CreationBottomSheetState()));
    });

    test('initial state with existing thing is correct', () {
      final bloc = CreationBottomSheetBloc(
        thingRepository: thingRepository,
        existingThing: existingThing,
      );
      expect(
        bloc.state,
        equals(
          const CreationBottomSheetState(
            content: 'Test Thing',
            isTextFieldEmpty: false,
          ),
        ),
      );
    });

    blocTest<CreationBottomSheetBloc, CreationBottomSheetState>(
      'emits updated state when ContentChanged is added',
      build: () => CreationBottomSheetBloc(thingRepository: thingRepository),
      act: (bloc) => bloc.add(const ContentChanged('New Content')),
      expect: () => [
        const CreationBottomSheetState(
          content: 'New Content',
          isTextFieldEmpty: false,
        ),
      ],
    );

    blocTest<CreationBottomSheetBloc, CreationBottomSheetState>(
      'emits updated state when ContentChanged is added with empty content',
      build: () => CreationBottomSheetBloc(thingRepository: thingRepository),
      act: (bloc) => bloc.add(const ContentChanged('  ')),
      expect: () => [
        const CreationBottomSheetState(
          content: '  ',
          isTextFieldEmpty: true,
        ),
      ],
    );

    blocTest<CreationBottomSheetBloc, CreationBottomSheetState>(
      'emits updated state when ValueVisibilityToggled is added',
      build: () => CreationBottomSheetBloc(
        thingRepository: thingRepository,
        existingThing: existingThing,
      ),
      act: (bloc) => bloc.add(const ValueVisibilityToggled()),
      expect: () => [
        const CreationBottomSheetState(
          content: 'Test Thing',
          isTextFieldEmpty: false,
          isValueFieldVisible: true,
        ),
      ],
    );

    blocTest<CreationBottomSheetBloc, CreationBottomSheetState>(
      'does not toggle value visibility when text field is empty',
      build: () => CreationBottomSheetBloc(thingRepository: thingRepository),
      act: (bloc) => bloc.add(const ValueVisibilityToggled()),
      expect: () => [],
    );

    blocTest<CreationBottomSheetBloc, CreationBottomSheetState>(
      'emits updated state when ValueChanged is added',
      build: () => CreationBottomSheetBloc(thingRepository: thingRepository),
      act: (bloc) => bloc.add(const ValueChanged('42.5')),
      expect: () => [
        const CreationBottomSheetState(
          value: 42.5,
        ),
      ],
    );

    blocTest<CreationBottomSheetBloc, CreationBottomSheetState>(
      'emits success state when FormSubmitted is added for new thing',
      build: () => CreationBottomSheetBloc(
        thingRepository: thingRepository,
        existingThing: null,
        parentId: 1,
      ),
      seed: () => const CreationBottomSheetState(
        content: 'New Thing',
        isTextFieldEmpty: false,
      ),
      act: (bloc) {
        when(
          () => thingRepository.addThing(
            thing: any(named: 'thing'),
            parentId: 1,
          ),
        ).thenAnswer((_) {});
        bloc.add(const FormSubmitted());
      },
      expect: () => [
        const CreationBottomSheetState(
          content: 'New Thing',
          isTextFieldEmpty: false,
          status: CreationBottomSheetStatus.success,
        ),
      ],
      verify: (_) {
        verify(
          () => thingRepository.addThing(
            thing: any(named: 'thing'),
            parentId: 1,
          ),
        ).called(1);
      },
    );

    blocTest<CreationBottomSheetBloc, CreationBottomSheetState>(
      'emits success state when FormSubmitted is added for existing thing',
      build: () {
        when(() => existingThing.content).thenReturn('Existing Thing');
        return CreationBottomSheetBloc(
          thingRepository: thingRepository,
          existingThing: existingThing,
        );
      },
      act: (bloc) {
        when(
          () => thingRepository.editThing(
            thing: any(named: 'thing'),
          ),
        ).thenAnswer((_) {});
        bloc.add(const FormSubmitted());
      },
      expect: () => [
        const CreationBottomSheetState(
          content: 'Existing Thing',
          isTextFieldEmpty: false,
          status: CreationBottomSheetStatus.success,
        ),
      ],
      verify: (_) {
        verify(
          () => thingRepository.editThing(
            thing: any(named: 'thing'),
          ),
        ).called(1);
      },
    );

    blocTest<CreationBottomSheetBloc, CreationBottomSheetState>(
      'does not emit new state when FormSubmitted is added with empty text field',
      build: () => CreationBottomSheetBloc(thingRepository: thingRepository),
      act: (bloc) => bloc.add(const FormSubmitted()),
      expect: () => [],
    );
  });
}
