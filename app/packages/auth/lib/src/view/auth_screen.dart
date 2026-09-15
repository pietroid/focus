import 'package:app_ui/app_ui.dart';
import 'package:auth/src/auth_bloc/auth_bloc.dart';
import 'package:auth/src/data/auth_repository.dart';
import 'package:auth/src/models/app_user.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template auth_screen}
/// Basic authentication screen with Google sign-in.
/// {@endtemplate}
class AuthScreen extends StatelessWidget {
  /// {@macro auth_screen}
  const AuthScreen({
    this.authRepository,
    this.onUserAuthenticated,
    this.onAuthenticated,
    super.key,
  });

  /// Repository used for authentication operations.
  ///
  /// Defaults to [FirebaseAuthRepository] when not provided.
  final AuthRepository? authRepository;

  /// Called with the authenticated user after a successful sign-in so the
  /// caller can create the user record on the backend.
  final Future<void> Function(AppUser user)? onUserAuthenticated;

  /// Called when the user has successfully signed in.
  final VoidCallback? onAuthenticated;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(
        authRepository: authRepository ?? FirebaseAuthRepository(),
        onUserAuthenticated: onUserAuthenticated,
      ),
      child: _AuthScreenView(onAuthenticated: onAuthenticated),
    );
  }
}

class _AuthScreenView extends StatelessWidget {
  const _AuthScreenView({this.onAuthenticated});

  final VoidCallback? onAuthenticated;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          onAuthenticated?.call();
        }
        if (state.status == AuthStatus.failure) {
          _showError(context, state.errorMessage ?? 'Authentication failed');
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s6,
              vertical: AppSpacing.s8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/icon.png', height: 160),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  'Focus',
                  textAlign: TextAlign.center,
                  style: AppTypography.headline,
                ),
                const SizedBox(height: AppSpacing.s12),
                BlocBuilder<AuthBloc, AuthState>(
                  buildWhen: (previous, current) =>
                      previous.status != current.status,
                  builder: (context, state) {
                    if (state.status == AuthStatus.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton.icon(
                          onPressed: () => context.read<AuthBloc>().add(
                            const AuthGoogleSignInRequested(),
                          ),
                          icon: const AppIcon(
                            iconData: AppIcons.google,
                            color: AppColors.onAccent,
                          ),
                          text: 'Entrar com Google',
                          expand: true,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
