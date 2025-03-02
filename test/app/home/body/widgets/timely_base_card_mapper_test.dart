import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/creation_bottom_sheet/view/creation_bottom_sheet.dart';
import 'package:focus/app/home/body/widgets/timely_base_card_mapper.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:things/things.dart';

class MockThing extends Mock implements Thing {}

class MockThingRepository extends Mock implements ThingRepository {}

class MockCreationBottomSheet extends Mock implements CreationBottomSheet {}

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('TimelyBaseCardMapper', () {
    late Thing thing;
    late ThingRepository thingRepository;
    late CreationBottomSheet creationBottomSheet;
    late BuildContext context;

    setUp(() {
      thing = MockThing();
      thingRepository = MockThingRepository();
      creationBottomSheet = MockCreationBottomSheet();
      context = MockBuildContext();

      when(() => thing.id).thenReturn(1);
      when(() => thing.content).thenReturn('Test Thing');
      when(() => thing.done).thenReturn(false);
      when(() => thing.parents).thenReturn(ToMany(items: [thing]));
      when(() => context.read<ThingRepository>()).thenReturn(thingRepository);
      when(() => context.read<CreationBottomSheet>())
          .thenReturn(creationBottomSheet);
    });

    test('toBaseCardParams maps thing properties correctly', () {
      final params = thing.toBaseCardParams(context);

      expect(params.title, equals('Test Thing'));
      expect(params.id, equals(1));
      expect(params.isDone, isFalse);
    });
  });
}
