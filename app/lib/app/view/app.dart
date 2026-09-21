import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/app.dart';
import 'package:focus/l10n/l10n.dart';
import 'package:focus/shell/shell.dart';
import 'package:focus/solved/solved.dart';
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
           GoRoute(path: '/', builder: (context, state) => const ShellPage()),
           // A new thread and an existing one are the same screen. The new one
           // carries its first message as `extra` and has no slug until the
           // server has given it one.
           GoRoute(
             path: '/chat',
             builder: (context, state) =>
                 ChatPage(initialMessage: state.extra as String?),
           ),
           GoRoute(
             path: '/chat/:slug',
             builder: (context, state) =>
                 ChatPage(slug: state.pathParameters['slug']),
           ),
           // The solved threads, which the timeline no longer shows.
           GoRoute(
             path: '/concluidos',
             builder: (context, state) => const SolvedPage(),
           ),
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
        } else {
          // The day is per user, so it is fetched once the user is known
          // rather than when the home screen happens to be built.
          context.read<TimelineBloc>().add(const TimelineRequested());
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
