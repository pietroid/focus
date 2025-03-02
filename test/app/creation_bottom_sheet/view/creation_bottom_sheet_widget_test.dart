import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/creation_bottom_sheet/view/creation_bottom_sheet_widget.dart';
import 'package:focus/app/creation_bottom_sheet/widgets/field_button.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:things/things.dart';
import 'package:app_ui/app_ui.dart';

class MockThingRepository extends Mock implements ThingRepository {}

void main() {
  late MockThingRepository mockThingRepository;

  setUp(() {
    mockThingRepository = MockThingRepository();
  });

  testWidgets('CreationBottomSheetWidget renders correctly',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreationBottomSheetWidget(
            thingRepository: mockThingRepository,
          ),
        ),
      ),
    );

    // Assert
    expect(find.byType(CreationBottomSheetWidget), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
      'When text field is empty, the accessory buttons must be disabled',
      (tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreationBottomSheetWidget(
            thingRepository: mockThingRepository,
          ),
        ),
      ),
    );

    // Assert
    final valueButton = find.byType(FieldButton).first;
    final durationButton = find.byType(FieldButton).last;

    final valueButtonWidget = tester.widget<FieldButton>(valueButton);
    expect(valueButtonWidget.disabled, true);

    final durationButtonWidget = tester.widget<FieldButton>(durationButton);
    expect(durationButtonWidget.disabled, true);
  });

  testWidgets('When text is typed, the accessory buttons must be enabled',
      (tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreationBottomSheetWidget(
            thingRepository: mockThingRepository,
          ),
        ),
      ),
    );

    // Act
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'Test');
    await tester.pump();

    // Assert
    final valueButton = find.byType(FieldButton).first;
    final durationButton = find.byType(FieldButton).last;

    final valueButtonWidget = tester.widget<FieldButton>(valueButton);
    expect(valueButtonWidget.disabled, false);

    final durationButtonWidget = tester.widget<FieldButton>(durationButton);
    expect(durationButtonWidget.disabled, false);
  });

  testWidgets(
      'When tapping on the first button, it must show a new text field on the right side of the current text field',
      (tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreationBottomSheetWidget(
            thingRepository: mockThingRepository,
          ),
        ),
      ),
    );

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'Test');
    await tester.pump();

    // Act
    final valueButton = find.byType(FieldButton).first;
    await tester.tap(valueButton);
    await tester.pump();

    // Assert
    expect(find.byType(TextField), findsNWidgets(2));
    
    // Verify the second text field has the correct properties
    final textFields = tester.widgetList<TextField>(find.byType(TextField));
    final secondTextField = textFields.elementAt(1);
    
    expect(secondTextField.keyboardType, TextInputType.number);
    expect(secondTextField.decoration?.hintText, 'Valor');
  });
}
