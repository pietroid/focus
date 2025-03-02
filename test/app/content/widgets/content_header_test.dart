import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/content/widgets/content_header.dart';
import 'package:mocktail/mocktail.dart';
import 'package:things/things.dart';

class MockThing extends Mock implements Thing {}

void main() {
  group('ContentHeader', () {
    late Thing thing;
    setUp(() {
      thing = MockThing();
      when(() => thing.content).thenReturn('Test Title');
    });
    testWidgets('renders title only', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentHeader(
              thing: MockThing(),
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
    });
  });
}
