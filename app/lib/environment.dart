import 'dart:developer';

import 'package:auth/auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:focus/firebase_options_dev.dart' as dev;
import 'package:focus/firebase_options_production.dart' as prod;

/// Which build this is: `production` or `dev`.
///
/// Read from `FLAVOR` in the `env/*.json` file the build was made with. A
/// build with no value is production, so nothing forgotten opens a door.
const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'production');

/// Whether this build is production.
const isProduction = flavor == 'production';

/// The Firebase project this build signs in against.
///
/// Production uses focus-production and the dev build uses focus-local-dev.
/// The app and the background refresh isolate both start from here, so they
/// never disagree about whose user is signed in.
FirebaseOptions firebaseOptions() {
  switch (flavor) {
    case 'dev':
      return dev.DefaultFirebaseOptions.currentPlatform;
    case 'production':
    default:
      return prod.DefaultFirebaseOptions.currentPlatform;
  }
}

/// Whether the sign-in screen draws the test account's email form.
///
/// Never true in production, whatever the env file says.
const bool testSignInEnabled =
    !isProduction && bool.fromEnvironment('ENABLE_TEST_LOGIN');

/// The account an E2E build signs in with by itself, with no screen to type
/// it into. Empty in every other build.
const _testLoginEmail = String.fromEnvironment('TEST_LOGIN_EMAIL');
const _testLoginPassword = String.fromEnvironment('TEST_LOGIN_PASSWORD');

/// Signs the E2E account in at launch, when the build names one, then hands
/// the user to [onSignedIn] so its record is created on the backend the way
/// a real sign-in would do it.
///
/// A failure is logged and swallowed: the app then opens on the landing page,
/// which is exactly what a flow waiting for the signed-in app notices.
Future<void> signInTestAccountIfAsked(
  AuthRepository auth, {
  required Future<void> Function(AppUser user) onSignedIn,
}) async {
  if (isProduction || _testLoginEmail.isEmpty) return;
  try {
    if (auth.currentUser?.email != _testLoginEmail) {
      await auth.signInWithEmail(
        email: _testLoginEmail,
        password: _testLoginPassword,
      );
    }
    final user = await auth.user.firstWhere((user) => user != null);
    await onSignedIn(user!);
  } on Object catch (error, stackTrace) {
    log(
      'test account sign-in failed',
      name: 'auth',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// `host:port` of a local Firebase Auth emulator, or empty for the real one.
const _authEmulatorHost = String.fromEnvironment('AUTH_EMULATOR_HOST');

/// Connects Firebase Auth to the emulator when the build names one.
///
/// Called after `Firebase.initializeApp` and before anything reads the user,
/// in the app and in the background isolate alike.
Future<void> connectAuthEmulatorIfAsked() async {
  if (_authEmulatorHost.isEmpty || isProduction) return;
  await useAuthEmulator(_authEmulatorHost);
}

/// Builds the semantics tree on web from the first frame, outside
/// production.
///
/// Flutter web draws to a canvas, so a test driver sees an empty page until
/// the semantics tree exists. With it, every label and every
/// `Semantics(identifier: ...)` becomes a DOM node that Maestro can find.
/// Production leaves it to the browser's own accessibility request.
void ensureSemanticsForTests() {
  if (!kIsWeb || isProduction) return;
  SemanticsBinding.instance.ensureSemantics();
}
