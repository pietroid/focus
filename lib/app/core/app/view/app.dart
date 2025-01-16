import 'package:flutter/material.dart';
import 'package:focus/app/core/home/core/sections/timely/timely_data.dart';
import 'package:focus/app/data/object_box.dart';
import 'package:focus/app/data/repositories/thing_repository.dart';
import 'package:focus/app/ui/app_colors.dart';
import 'package:focus/app/ui/creation_bottom_sheet.dart';
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
          create: (context) => TimelyData(
            box: objectBox,
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
          useMaterial3: true,
          textTheme: GoogleFonts.onestTextTheme(ThemeData().textTheme).copyWith(
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
