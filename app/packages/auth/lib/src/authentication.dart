import 'package:auth/src/data/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Whether the current user is signed in.
///
/// Waits for Firebase Auth to restore the persisted auth state before
/// returning.
Future<bool> isUserAuthenticated() {
  return FirebaseAuthRepository().isAuthenticated();
}

/// Points Firebase Auth at the emulator listening on [hostAndPort], as in
/// `localhost:9099`.
///
/// Local runs use it so the test account lives on the laptop instead of in
/// the production project.
Future<void> useAuthEmulator(String hostAndPort) async {
  final separator = hostAndPort.lastIndexOf(':');
  final host = separator < 0
      ? hostAndPort
      : hostAndPort.substring(0, separator);
  final port = separator < 0
      ? 9099
      : int.parse(hostAndPort.substring(separator + 1));
  await FirebaseAuth.instance.useAuthEmulator(host, port);
}
