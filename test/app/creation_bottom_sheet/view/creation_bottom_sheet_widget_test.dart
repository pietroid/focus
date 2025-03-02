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
    final valueButton = find.byIcon(Icons.attach_money);
    final durationButton = find.byIcon(Icons.timer_outlined);

    final valueButtonIcon = tester.widget<Icon>(valueButton);
    final valueButtonColor = valueButtonIcon.color;
    expect(valueButtonColor, AppColors.disabledCardColor);

    final durationButtonIcon = tester.widget<Icon>(durationButton);
    final durationButtonColor = durationButtonIcon.color;
    expect(durationButtonColor, AppColors.disabledCardColor);
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
}
