import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/focus/view/global_scaffold.dart';
import 'package:focus/app/focus/widgets/creation_bottom_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockCreationBottomSheet extends Mock implements CreationBottomSheet {}

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  group('GlobalScaffold', () {
    late CreationBottomSheet creationBottomSheet;

    setUp(() {
      creationBottomSheet = MockCreationBottomSheet();
    });

    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<CreationBottomSheet>.value(value: creationBottomSheet),
            ],
            child: const GlobalScaffold(
              child: Text('Test Child'),
            ),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });
  });
}
