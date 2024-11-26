import 'package:cron/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter().router,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0C1116),
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
    );
  }
}
