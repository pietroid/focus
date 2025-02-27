import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/focus/widgets/creation_bottom_sheet.dart';
import 'package:focus/app/home/body/bloc/home_body_cubit.dart';
import 'package:for_you_repository/for_you_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:local_service/local_service.dart';
import 'package:provider/provider.dart';
import 'package:things/things.dart';
import 'package:timely_repository/timely_repository.dart';
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
        Provider(create: (context) => TimelyRepository(box: objectBox)),
        Provider(create: (context) => ForYouRepository(box: objectBox)),
        BlocProvider(
          create: (context) => HomeBodyCubit(
            timelyRepository: context.read<TimelyRepository>(),
            forYouRepository: context.read<ForYouRepository>(),
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
