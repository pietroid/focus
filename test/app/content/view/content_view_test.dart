import 'package:content_repository/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/content/view/content_view.dart';
import 'package:local_service/local_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rxdart/subjects.dart';

class MockObjectBox extends Mock implements ObjectBox {}

class MockContentRepository extends Mock implements ContentRepository {}

void main() {
  group('ContentScreen', () {
    late ContentRepository contentRepository;

    setUp(() {
      contentRepository = MockContentRepository();

      when(() => contentRepository.stream(thingId: 1)).thenAnswer(
        (_) => BehaviorSubject.seeded([]),
      );
    });

    testWidgets('renders ContentView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiRepositoryProvider(
            providers: [
              RepositoryProvider.value(value: contentRepository),
            ],
            child: const ContentView(
              thingId: 1,
            ),
          ),
        ),
      );

      expect(find.byType(ContentView), findsOneWidget);
    });
  });
}
