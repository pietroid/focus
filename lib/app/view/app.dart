import 'package:cron/core/data/repositories/note_repository.dart';
import 'package:cron/core/domain/use_cases/note_use_cases.dart';
import 'package:cron/core/view/creation_bottom_sheet.dart';
import 'package:cron/routing/app_router.dart';
import 'package:cron/shared/object_box.dart';
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
          create: (context) => NoteRepository(box: objectBox),
        ),
        Provider(
          create: (context) => NoteUseCases(
            noteRepository: context.read<NoteRepository>(),
          ),
        ),
        Provider(
          create: (context) => CreationBottomSheet(
            noteUseCases: context.read<NoteUseCases>(),
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: AppRouter().router,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF00ACBB),
          scaffoldBackgroundColor: const Color(0xFF0C1116),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xFF0C1116),
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
