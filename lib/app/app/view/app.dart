import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/focus/widgets/creation_bottom_sheet.dart';
import 'package:focus/app/home_header/bloc/clock_cubit.dart';
import 'package:focus/app/for_you/bloc/for_you_cubit.dart';
import 'package:focus/app/for_you/bloc/for_you_tab_cubit.dart';
import 'package:focus/app/for_you/data/for_you_repository.dart';
import 'package:focus/app/home_timely_section/bloc/timely_cubit.dart';
import 'package:focus/app/home_timely_section/data/timely_repository.dart';
import 'package:focus/app/thing/data/thing_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:local_service/local_service.dart';
import 'package:provider/provider.dart';
import 'package:timer/timer.dart';

class App extends StatelessWidget {
  const App({
    required this.router,
    required this.objectBox,
    super.key,
  });
  final ObjectBox objectBox;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(
          create: (context) => objectBox,
        ),
        Provider(
          create: (context) => ThingRepository(box: objectBox),
        ),
        Provider(
          create: (context) => TimerRepository(),
        ),
        Provider(
          create: (context) => CreationBottomSheet(
            thingRepository: context.read<ThingRepository>(),
          ),
        ),
        Provider(
          create: (context) =>
              TimelyCubit(timelyRepository: TimelyRepository(box: objectBox)),
        ),
        Provider(
          create: (context) =>
              ForYouCubit(forYouRepository: ForYouRepository(box: objectBox)),
        ),
        BlocProvider(
          create: (context) => ForYouTabCubit(
            initialTab: ForYouRepository(box: objectBox)
                .stream
                .value
                .first
                .children
                .first,
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        themeMode: ThemeMode.dark,
        darkTheme: AppTheme().themeData,
      ),
    );
  }
}
