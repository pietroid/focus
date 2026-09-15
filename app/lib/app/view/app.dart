import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/app.dart';
import 'package:focus/home/home.dart';
import 'package:focus/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:subject/subject.dart';

/// {@template app}
/// Root widget for the Focus application.
/// {@endtemplate}
class App extends StatelessWidget {
  /// {@macro app}
  App({
    required String initialLocation,
    required Future<void> Function(AppUser user) onUserAuthenticated,
    super.key,
  }) : _router = GoRouter(
         initialLocation: initialLocation,
         routes: [
           GoRoute(path: '/', builder: (context, state) => const HomePage()),
           GoRoute(
             path: '/auth',
             builder: (context, state) => AuthScreen(
               authRepository: context.read<AuthRepository>(),
               onUserAuthenticated: onUserAuthenticated,
               onAuthenticated: () => context.go('/'),
             ),
           ),
           GoRoute(
             path: '/subject/:id',
             builder: (context, state) => SubjectPage(
               subjectId: state.pathParameters['id']!,
               uploadButtonLabel: context.l10n.uploadButton,
               onHomePressed: () => context.go('/'),
             ),
           ),
         ],
       );

  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen: (previous, current) =>
          (previous.status != AppStatus.authenticated &&
              current.status == AppStatus.authenticated) ||
          current.status == AppStatus.unauthenticated,
      listener: (context, state) {
        if (state.status == AppStatus.unauthenticated) {
          _router.go('/auth');
          return;
        }

        context.read<SubjectBloc>().add(const SubjectsRequested());
      },
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
      ),
    );
  }
}
