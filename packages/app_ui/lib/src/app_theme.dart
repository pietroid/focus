import 'package:app_ui/src/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  ThemeData get themeData => ThemeData(
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
            letterSpacing: 0.1,
            color: Color.fromARGB(217, 255, 255, 255),
          ),
        ),
      );
}
