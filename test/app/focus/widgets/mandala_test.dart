import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/focus/widgets/mandala.dart';

void main() {
  group('Mandala', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Mandala(),
          ),
        ),
      );

      expect(find.byType(Mandala), findsOneWidget);
      expect(find.byType(AnimatedBuilder), findsAny);
    });
  });
}
