part of 'auth_bloc.dart';

/// {@template auth_event}
/// Base class for all authentication events.
/// {@endtemplate}
abstract class AuthEvent extends Equatable {
  /// {@macro auth_event}
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// {@template auth_started}
/// Starts listening to authentication state changes.
/// {@endtemplate}
class AuthStarted extends AuthEvent {
  /// {@macro auth_started}
  const AuthStarted();
}

/// {@template auth_google_sign_in_requested}
/// Request to sign in with Google.
/// {@endtemplate}
class AuthGoogleSignInRequested extends AuthEvent {
  /// {@macro auth_google_sign_in_requested}
  const AuthGoogleSignInRequested();
}

/// {@template auth_email_sign_in_requested}
/// Request to sign in with the test account's email and password.
/// {@endtemplate}
class AuthEmailSignInRequested extends AuthEvent {
  /// {@macro auth_email_sign_in_requested}
  const AuthEmailSignInRequested({required this.email, required this.password});

  /// The account's email.
  final String email;

  /// The account's password.
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// {@template auth_failure_occurred}
/// Authentication failed with [message].
/// {@endtemplate}
class AuthFailureOccurred extends AuthEvent {
  /// {@macro auth_failure_occurred}
  const AuthFailureOccurred(this.message);

  /// Failure message.
  final String message;

  @override
  List<Object?> get props => [message];
}
