import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus/app/home/body/bloc/home_body_cubit.dart';
import 'package:focus/app/home/body/view/body.dart';
import 'package:mocktail/mocktail.dart';
import 'package:things/things.dart';
import 'package:provider/provider.dart';

class MockHomeBodyCubit extends Mock implements HomeBodyCubit {}
class MockHomeBodyState extends Mock implements HomeBodyState {}
class MockThingRepository extends Mock implements ThingRepository {}
class MockThing extends Mock implements Thing {}

void main() {
  group('HomeBody', () {
    late HomeBodyCubit cubit;
    late HomeBodyState state;
    late ThingRepository thingRepository;
    late Thing mockThing;

    setUp(() {
      cubit = MockHomeBodyCubit();
      state = MockHomeBodyState();
      thingRepository = MockThingRepository();
      mockThing = MockThing();

      when(() => mockThing.id).thenReturn(1);
      when(() => state.allSections).thenReturn([]);
      when(() => cubit.state).thenReturn(state);
    });

    testWidgets('renders NestedDraggableList', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<ThingRepository>.value(value: thingRepository),
              BlocProvider<HomeBodyCubit>.value(value: cubit),
            ],
            child: const HomeBody(),
          ),
        ),
      );

      expect(find.byType(HomeBody), findsOneWidget);
    });
  });
}
