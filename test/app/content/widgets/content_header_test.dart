import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/content/widgets/content_header.dart';

void main() {
  group('ContentHeader', () {
    testWidgets('renders title only', (tester) async {
      const title = 'Test Title';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentHeader(
              const ContentHeaderParams(title: title),
            ),
          ),
        ),
      );

      expect(find.text(title), findsOneWidget);
    });
  });
}
