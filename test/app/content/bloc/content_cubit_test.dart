import 'package:bloc_test/bloc_test.dart';
import 'package:content_repository/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/content/bloc/content_cubit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rxdart/subjects.dart';
import 'package:things/things.dart';

class MockContentRepository extends Mock implements ContentRepository {}

void main() {
  group('ContentCubit', () {
    late ContentRepository contentRepository;

    setUp(() {
      contentRepository = MockContentRepository();
      when(() => contentRepository.stream(thingId: 1)).thenAnswer(
        (_) => BehaviorSubject.seeded([]),
      );
    });

    test('initial state is empty list', () {
      final cubit =
          ContentCubit(contentRepository: contentRepository, thingId: 1);
      expect(cubit.state, isEmpty);
    });
  });
}
