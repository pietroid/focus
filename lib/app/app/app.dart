import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/home/sections/body/for_you/core/for_you_cubit.dart';
import 'package:focus/app/home/sections/body/for_you/data/for_you_repository.dart';
import 'package:focus/app/home/sections/body/timely/core/timely_cubit.dart';
import 'package:focus/app/home/sections/header/data/timer/timer_cubit.dart';
import 'package:focus/app/home/sections/body/timely/data/timely_repository.dart';
import 'package:focus/app/common_infrastructure/data/object_box.dart';
import 'package:focus/app/thing/data/thing_repository.dart';
import 'package:focus/app/app/ui/app_colors.dart';
import 'package:focus/app/focus/core/creation_bottom_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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
          create: (context) => TimerCubit(
            startTime: DateTime.now(),
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: AppColors.primaryColor,
          scaffoldBackgroundColor: AppColors.defaultBackgroundColor,
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: AppColors.defaultBackgroundColor,
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Colors.white,
            selectionColor: Colors.white,
            selectionHandleColor: Colors.white,
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.onestTextTheme(ThemeData().textTheme).copyWith(
            displayMedium: const TextStyle(
              fontSize: 40,
              color: Colors.white,
            ),
            headlineLarge: const TextStyle(
              fontSize: 30,
              color: Colors.white,
            ),
            headlineMedium: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
            bodySmall: const TextStyle(
              fontSize: 12,
              color: Color.fromARGB(160, 255, 255, 255),
            ),
          ),
        ),
      ),
    );
  }
}
