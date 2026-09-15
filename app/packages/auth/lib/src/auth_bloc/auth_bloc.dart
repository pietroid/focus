import 'package:auth/src/data/auth_repository.dart';
import 'package:auth/src/models/app_user.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// {@template auth_bloc}
/// Manages authentication state and sign-in flows.
/// {@endtemplate}
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// {@macro auth_bloc}
  AuthBloc({
    required this._authRepository,
    this.onUserAuthenticated,
  }) : super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthFailureOccurred>(_onFailureOccurred);

    add(const AuthStarted());
  }

  final AuthRepository _authRepository;

  /// Called with the authenticated user after a successful sign-in so the
  /// caller can create the user record on the backend.
  final Future<void> Function(AppUser user)? onUserAuthenticated;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    await emit.forEach(
      _authRepository.user,
      onData: (user) => user != null
          ? state.copyWith(
              status: AuthStatus.authenticated,
              user: user,
            )
          : const AuthState(status: AuthStatus.unauthenticated),
      onError: (error, stackTrace) => state.copyWith(
        status: AuthStatus.failure,
        errorMessage: 'Authentication stream error',
      ),
    );
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _authRepository.signInWithGoogle();
      await _ensureUserRecord(emit);
    } on FirebaseAuthException catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: e.message ?? 'Google sign in failed',
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _ensureUserRecord(Emitter<AuthState> emit) async {
    final user = await _authRepository.user.firstWhere((user) => user != null);
    if (user != null) {
      await onUserAuthenticated?.call(user);
    }
  }

  void _onFailureOccurred(
    AuthFailureOccurred event,
    Emitter<AuthState> emit,
  ) {
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        errorMessage: event.message,
      ),
    );
  }
}
