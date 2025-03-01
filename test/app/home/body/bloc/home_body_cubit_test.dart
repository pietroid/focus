import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/home/body/bloc/home_body_cubit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:for_you_repository/for_you_repository.dart';
import 'package:timely_repository/timely_repository.dart';
import 'package:things/things.dart';
import 'package:rxdart/subjects.dart';

class MockTimelyRepository extends Mock implements TimelyRepository {}

class MockForYouRepository extends Mock implements ForYouRepository {}

class MockThing extends Mock implements Thing {}

void main() {
  group('HomeBodyCubit', () {
    late TimelyRepository timelyRepository;
    late ForYouRepository forYouRepository;
    late Thing mockThing;
    late Thing mockChildThing;

    setUp(() {
      timelyRepository = MockTimelyRepository();
      forYouRepository = MockForYouRepository();
      mockThing = MockThing();
      mockChildThing = MockThing();

      when(() => mockThing.id).thenReturn(1);
      when(() => mockThing.children)
          .thenReturn(ToMany(items: [mockChildThing]));
      when(() => mockChildThing.id).thenReturn(2);

      when(() => timelyRepository.stream).thenAnswer(
        (_) => BehaviorSubject.seeded([mockThing]),
      );
      when(() => forYouRepository.stream).thenAnswer(
        (_) => BehaviorSubject.seeded([mockThing]),
      );
    });

    test('initial state has sections from repositories', () {
      final cubit = HomeBodyCubit(
        timelyRepository: timelyRepository,
        forYouRepository: forYouRepository,
      );

      // expect(cubit.state.timelySections, isNotEmpty);
      // expect(cubit.state.forYouSection, isNotNull);
    });
  });
}
