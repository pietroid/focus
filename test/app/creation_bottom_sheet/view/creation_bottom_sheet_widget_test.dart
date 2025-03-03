import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/creation_bottom_sheet/bloc/creation_bottom_sheet_bloc.dart';
import 'package:focus/app/creation_bottom_sheet/view/creation_bottom_sheet_widget.dart';
import 'package:focus/app/creation_bottom_sheet/widgets/field_button.dart';
import 'package:mocktail/mocktail.dart';
import 'package:things/things.dart';

class MockThingRepository extends Mock implements ThingRepository {}
class MockCreationBottomSheetBloc extends MockBloc<CreationBottomSheetEvent, CreationBottomSheetState> implements CreationBottomSheetBloc {}

void main() {
  late MockThingRepository mockThingRepository;
  late MockCreationBottomSheetBloc mockBloc;

  setUp(() {
    mockThingRepository = MockThingRepository();
    mockBloc = MockCreationBottomSheetBloc();
  });

  Widget createWidgetUnderTest({Thing? existingThing, int? parentId}) {
    return MaterialApp(
      home: Scaffold(
        body: CreationBottomSheetWidget(
          thingRepository: mockThingRepository,
          existingThing: existingThing,
          parentId: parentId,
        ),
      ),
    );
  }

  Widget createWidgetWithMockBloc({CreationBottomSheetState? state}) {
    when(() => mockBloc.state).thenReturn(
      state ?? const CreationBottomSheetState(),
    );

    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<CreationBottomSheetBloc>.value(
          value: mockBloc,
          child: const _CreationBottomSheetView(),
        ),
      ),
    );
  }

  group('CreationBottomSheetWidget', () {
    testWidgets('renders correctly', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.byType(CreationBottomSheetWidget), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('creates bloc with correct parameters', (tester) async {
      // Arrange
      final thing = Thing(
        content: 'Test Thing',
        createdAt: DateTime.now(),
      );
      const parentId = 42;

      // Act
      await tester.pumpWidget(
        createWidgetUnderTest(
          existingThing: thing,
          parentId: parentId,
        ),
      );

      // Assert
      expect(find.byType(BlocProvider<CreationBottomSheetBloc>), findsOneWidget);
    });
  });

  group('_CreationBottomSheetView', () {
    testWidgets('when text field is empty, the accessory buttons must be disabled',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        createWidgetWithMockBloc(
          state: const CreationBottomSheetState(
            isTextFieldEmpty: true,
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

    testWidgets('when text is not empty, the accessory buttons must be enabled',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        createWidgetWithMockBloc(
          state: const CreationBottomSheetState(
            content: 'Test',
            isTextFieldEmpty: false,
          ),
        ),
      );

      // Assert
      final valueButton = find.byType(FieldButton).first;
      final durationButton = find.byType(FieldButton).last;

      final valueButtonWidget = tester.widget<FieldButton>(valueButton);
      expect(valueButtonWidget.disabled, false);

      final durationButtonWidget = tester.widget<FieldButton>(durationButton);
      expect(durationButtonWidget.disabled, false);
    });

    testWidgets('when value field is visible, it shows a second text field',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        createWidgetWithMockBloc(
          state: const CreationBottomSheetState(
            content: 'Test',
            isTextFieldEmpty: false,
            isValueFieldVisible: true,
          ),
        ),
      );

      // Assert
      expect(find.byType(TextField), findsNWidgets(2));
      
      // Verify the second text field has the correct properties
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      final secondTextField = textFields.elementAt(1);
      
      expect(secondTextField.keyboardType, TextInputType.number);
      expect(secondTextField.decoration?.hintText, 'Valor');
    });

    testWidgets('tapping value button adds ValueVisibilityToggled event',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        createWidgetWithMockBloc(
          state: const CreationBottomSheetState(
            content: 'Test',
            isTextFieldEmpty: false,
          ),
        ),
      );

      // Act
      final valueButton = find.byType(FieldButton).first;
      await tester.tap(valueButton);
      await tester.pump();

      // Assert
      verify(() => mockBloc.add(const ValueVisibilityToggled())).called(1);
    });

    testWidgets('submitting text field adds FormSubmitted event',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        createWidgetWithMockBloc(
          state: const CreationBottomSheetState(
            content: 'Test',
            isTextFieldEmpty: false,
          ),
        ),
      );

      // Act
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Test');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pump();

      // Assert
      verify(() => mockBloc.add(const FormSubmitted())).called(1);
    });

    testWidgets('pops when status is success', (tester) async {
      // Arrange
      final navigatorKey = GlobalKey<NavigatorState>();
      var didPop = false;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            body: BlocProvider<CreationBottomSheetBloc>.value(
              value: mockBloc,
              child: const _CreationBottomSheetView(),
            ),
          ),
        ),
      );

      // Mock the navigator pop
      navigatorKey.currentState!.pop = () {
        didPop = true;
      };

      // Initial state
      when(() => mockBloc.state).thenReturn(
        const CreationBottomSheetState(
          content: 'Test',
          isTextFieldEmpty: false,
        ),
      );
      await tester.pump();

      // Act - emit success state
      final blocListener = find.byType(BlocListener<CreationBottomSheetBloc, CreationBottomSheetState>);
      expect(blocListener, findsOneWidget);

      // Simulate state change to success
      whenListen(
        mockBloc,
        Stream.fromIterable([
          const CreationBottomSheetState(
            content: 'Test',
            isTextFieldEmpty: false,
            status: CreationBottomSheetStatus.success,
          ),
        ]),
      );

      // Update the current state
      when(() => mockBloc.state).thenReturn(
        const CreationBottomSheetState(
          content: 'Test',
          isTextFieldEmpty: false,
          status: CreationBottomSheetStatus.success,
        ),
      );
      
      await tester.pump();

      // Assert
      expect(didPop, true);
    });
  });
}
