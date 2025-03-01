import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/home/body/widgets/choice_selector.dart';

void main() {
  group('ChoiceSelector', () {
    testWidgets('renders label text', (tester) async {
      const label = 'Test Choice';
      
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChoiceSelector(
              label: label,
              isSelected: false,
            ),
          ),
        ),
      );

      expect(find.text(label), findsOneWidget);
    });
  });
}
