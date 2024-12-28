import 'package:cron/app/core/use_cases/thing_use_cases.dart';
import 'package:cron/app/data/object_box.dart';
import 'package:cron/app/data/repositories/thing_repository.dart';
import 'package:cron/app/ui/app_colors.dart';
import 'package:cron/app/ui/creation_bottom_sheet.dart';
import 'package:cron/app/ui/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({
    required this.objectBox,
    super.key,
  });
  final ObjectBox objectBox;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(
          create: (context) => ThingRepository(box: objectBox),
        ),
        Provider(
          create: (context) => ThingUseCases(
            thingRepository: context.read<ThingRepository>(),
          ),
        ),
        Provider(
          create: (context) => CreationBottomSheet(
            thingUseCases: context.read<ThingUseCases>(),
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: AppRouter().router,
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
