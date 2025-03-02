import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/creation_bottom_sheet/view/creation_bottom_sheet.dart';
import 'package:mocktail/mocktail.dart';
import 'package:things/things.dart';

class MockThingRepository extends Mock implements ThingRepository {}

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('CreationBottomSheet', () {
    late ThingRepository thingRepository;
    late BuildContext context;

    setUp(() {
      thingRepository = MockThingRepository();
      context = MockBuildContext();
    });

    test('can be instantiated', () {
      expect(
        CreationBottomSheet(thingRepository: thingRepository),
        isNotNull,
      );
    });

    testWidgets('shows bottom sheet content', (tester) async {
      final bottomSheet = CreationBottomSheet(thingRepository: thingRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => bottomSheet.show(context),
                child: const Text('Show Sheet'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheetWidget), findsOneWidget);
    });
  });
}
