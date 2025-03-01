import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/home/body/bloc/home_body_cubit.dart';
import 'package:focus/app/home/body/widgets/list_header.dart';
import 'package:mocktail/mocktail.dart';
import 'package:things/things.dart';

class MockHomeBodySection extends Mock implements HomeBodySection {}
class MockThing extends Mock implements Thing {}

void main() {
  group('ListHeader', () {
    late HomeBodySection section;
    late Thing mockThing;
    late VoidCallback onTap;

    setUp(() {
      section = MockHomeBodySection();
      mockThing = MockThing();
      onTap = () {};

      when(() => section.type).thenReturn(HomeBodySectionType.regular);
      when(() => section.mainThing).thenReturn(mockThing);
      when(() => mockThing.content).thenReturn('Test Header');
    });

    testWidgets('renders regular section header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListHeader(
              section: section,
              onTap: onTap,
            ),
          ),
        ),
      );

      expect(find.text('Test Header'), findsOneWidget);
    });
  });
}
