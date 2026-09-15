import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/app.dart';
import 'package:focus/home/home.dart';
import 'package:focus/l10n/l10n.dart';
import 'package:go_router/go_router.dart';

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
        }
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
