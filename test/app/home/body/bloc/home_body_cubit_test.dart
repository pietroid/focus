import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/home/body/bloc/home_body_cubit.dart';
import 'package:focus/app/home/body/mappers/home_body_section_mapper.dart';
import 'package:mocktail/mocktail.dart';
import 'package:for_you_repository/for_you_repository.dart';
import 'package:timely_repository/timely_repository.dart';
import 'package:things/things.dart';
import 'package:rxdart/subjects.dart';
import 'package:objectbox/objectbox.dart';

class MockTimelyRepository extends Mock implements TimelyRepository {}

class MockForYouRepository extends Mock implements ForYouRepository {}

class MockThing extends Mock implements Thing {
  @override
  ToMany<Thing> get children => _children;
  
  final ToMany<Thing> _children = ToMany<Thing>();
  
  void setChildren(List<Thing> value) {
    _children.clear();
    _children.addAll(value);
  }
}

void main() {
  group('HomeBodyCubit', () {
    late TimelyRepository timelyRepository;
    late ForYouRepository forYouRepository;
    late HomeBodySectionMapper homeBodySectionMapper;
    late MockThing mockThing;
    late MockThing mockChildThing;

    setUp(() {
      timelyRepository = MockTimelyRepository();
      forYouRepository = MockForYouRepository();
      homeBodySectionMapper = HomeBodySectionMapper();
      mockThing = MockThing();
      mockChildThing = MockThing();

      when(() => mockThing.id).thenReturn(1);
      mockThing.setChildren([mockChildThing]);
      when(() => mockChildThing.id).thenReturn(2);
      mockChildThing.setChildren([]);

      when(() => timelyRepository.stream).thenAnswer(
        (_) => BehaviorSubject.seeded([mockThing]),
      );
      when(() => forYouRepository.stream).thenAnswer(
        (_) => BehaviorSubject.seeded([mockThing]),
      );
    });

    HomeBodyCubit buildCubit() => HomeBodyCubit(
          timelyRepository: timelyRepository,
          forYouRepository: forYouRepository,
          homeBodySectionMapper: homeBodySectionMapper,
        );

    test('initial state has sections from repositories', () {
      final cubit = buildCubit();
      
      expect(cubit.state.timelySections, isNotEmpty);
      expect(cubit.state.forYouSection, isNotNull);
    });

    blocTest<HomeBodyCubit, HomeBodyState>(
      'emits updated state when timely repository stream emits',
      build: buildCubit,
      act: (cubit) {
        final newMockThing = MockThing();
        when(() => newMockThing.id).thenReturn(3);
        newMockThing.setChildren([]);
        
        timelyRepository.stream.add([newMockThing]);
      },
      expect: () => [
        isA<HomeBodyState>().having(
          (state) => state.timelySections,
          'timelySections',
          isNotEmpty,
        ),
      ],
    );

    blocTest<HomeBodyCubit, HomeBodyState>(
      'emits updated state when for you repository stream emits',
      build: buildCubit,
      act: (cubit) {
        final newMockThing = MockThing();
        when(() => newMockThing.id).thenReturn(3);
        final newChildThing = MockThing();
        when(() => newChildThing.id).thenReturn(4);
        newChildThing.setChildren([]);
        newMockThing.setChildren([newChildThing]);
        
        forYouRepository.stream.add([newMockThing]);
      },
      expect: () => [
        isA<HomeBodyState>().having(
          (state) => state.forYouSection,
          'forYouSection',
          isNotNull,
        ),
      ],
    );
  });
}
