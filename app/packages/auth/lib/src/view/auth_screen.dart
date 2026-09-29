import 'package:app_ui/app_ui.dart';
import 'package:auth/src/auth_bloc/auth_bloc.dart';
import 'package:auth/src/data/auth_repository.dart';
import 'package:auth/src/models/app_user.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template auth_screen}
/// The screen someone signs in on.
///
/// It owns the sign-in and reports how it went. What it draws around the
/// sign-in is up to [child], which places an [AuthSignInButton] wherever it
/// wants one. Without a [child] it is the logo, the name and a full-width
/// button.
/// {@endtemplate}
class AuthScreen extends StatelessWidget {
  /// {@macro auth_screen}
  const AuthScreen({
    this.authRepository,
    this.onUserAuthenticated,
    this.onAuthenticated,
    this.child,
    this.testSignIn = false,
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

  /// What the screen shows. It must hold an [AuthSignInButton].
  final Widget? child;

  /// Whether the test account's email form is drawn over [child].
  ///
  /// It exists so an automated run can get past Google, which no test driver
  /// can click through reliably. Builds for production leave it off.
  final bool testSignIn;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(
        authRepository: authRepository ?? FirebaseAuthRepository(),
        onUserAuthenticated: onUserAuthenticated,
      ),
      child: _AuthScreenView(
        onAuthenticated: onAuthenticated,
        child: testSignIn
            ? Stack(
                children: [
                  Positioned.fill(child: child ?? const _DefaultAuthBody()),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AuthTestSignInForm(),
                  ),
                ],
              )
            : child ?? const _DefaultAuthBody(),
      ),
    );
  }
}

class _AuthScreenView extends StatelessWidget {
  const _AuthScreenView({required this.child, this.onAuthenticated});

  final VoidCallback? onAuthenticated;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          onAuthenticated?.call();
        }
        if (state.status == AuthStatus.failure) {
          _showError(context, state.errorMessage ?? 'Não foi possível entrar');
        }
      },
      child: Scaffold(body: child),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DefaultAuthBody extends StatelessWidget {
  const _DefaultAuthBody();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            const AuthSignInButton(expand: true),
          ],
        ),
      ),
    );
  }
}

/// {@template auth_sign_in_button}
/// Starts the Google sign-in, and spins while it runs.
///
/// It reads the [AuthBloc] an [AuthScreen] provides, so it only works below
/// one.
/// {@endtemplate}
class AuthSignInButton extends StatelessWidget {
  /// {@macro auth_sign_in_button}
  const AuthSignInButton({
    this.expand = false,
    this.compact = false,
    this.label,
    super.key,
  });

  /// Whether the button stretches to the width of its parent.
  final bool expand;

  /// A quiet text button with no mark, for a screen that is about something
  /// else and only lets someone in on the side.
  final bool compact;

  /// The word on the button, for a screen written in another language.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final loading = context.select<AuthBloc, bool>(
      (bloc) => bloc.state.status == AuthStatus.loading,
    );

    if (loading) {
      return const SizedBox.square(
        dimension: AppSpacing.tapTarget,
        child: Center(
          child: SizedBox.square(
            dimension: AppSpacing.s5,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    void signIn() =>
        context.read<AuthBloc>().add(const AuthGoogleSignInRequested());

    if (compact) {
      return AppButton.text(
        onPressed: signIn,
        text: label ?? 'Entrar',
        expand: expand,
      );
    }

    return AppButton.icon(
      onPressed: signIn,
      icon: const AppIcon(iconData: AppIcons.google, color: AppColors.onAccent),
      text: label ?? 'Entrar com Google',
      expand: expand,
    );
  }
}

/// {@template auth_test_sign_in_form}
/// The test account's way in: an email, a password and a button.
///
/// Drawn only on builds that are not production, pinned to the foot
/// of the sign-in screen. Every field carries a semantics identifier so a
/// Maestro flow can find it without depending on the words around it.
/// {@endtemplate}
class AuthTestSignInForm extends StatefulWidget {
  /// {@macro auth_test_sign_in_form}
  const AuthTestSignInForm({super.key});

  @override
  State<AuthTestSignInForm> createState() => _AuthTestSignInFormState();
}

class _AuthTestSignInFormState extends State<AuthTestSignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) return;

    context.read<AuthBloc>().add(
      AuthEmailSignInRequested(email: email, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Conta de teste', style: AppTypography.label),
              Semantics(
                identifier: 'test-login-email',
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: 'E-mail'),
                ),
              ),
              Semantics(
                identifier: 'test-login-password',
                child: TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Senha'),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              Semantics(
                identifier: 'test-login-submit',
                child: AppButton.text(onPressed: _submit, text: 'Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
