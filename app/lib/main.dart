import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/app.dart';
import 'package:focus/bootstrap.dart';
import 'package:focus/firebase_options_production.dart' as prod;
import 'package:user/user.dart';

const _kGoogleSignInClientId = String.fromEnvironment(
  'GOOGLE_SIGN_IN_CLIENT_ID',
);
const _kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

class _AuthTokenProvider implements TokenProvider {
  _AuthTokenProvider(this._authRepository);

  final AuthRepository _authRepository;

  @override
  Future<String?> getToken() async {
    return _authRepository.currentUser?.getIdToken();
  }

  @override
  Future<String?> refreshToken() async {
    return _authRepository.currentUser?.getIdToken(true);
  }
}

Future<void> main() async {
  // The development Firebase project is no longer used; both flavors talk to
  // the production project. The flavor only controls the backend URL and the
  // app bundle ID.
  final options = prod.DefaultFirebaseOptions.currentPlatform;

  await _runAppWithFirebaseOptions(options);
}

Future<void> _runAppWithFirebaseOptions(FirebaseOptions firebaseOptions) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);

  final authRepository = FirebaseAuthRepository(
    clientId: kIsWeb ? _kGoogleSignInClientId : null,
  );
  final apiClient = ApiClient(
    baseUrl: _kApiBaseUrl,
    tokenProvider: _AuthTokenProvider(authRepository),
  );
  final userRepository = UserRepository(apiClient: apiClient);
  final chatRepository = ChatRepository(apiClient: apiClient);
  final timelineRepository = TimelineRepository(apiClient: apiClient);

  final initialUser = await authRepository.user.first;
  final initialLocation = initialUser == null ? '/auth' : '/';

  await bootstrap(
    () => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => authRepository),
        RepositoryProvider<ChatRepository>(create: (_) => chatRepository),
        RepositoryProvider<TimelineRepository>(
          create: (_) => timelineRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AppBloc>(
            create: (_) => AppBloc(
              authRepository: authRepository,
              initialUser: initialUser,
            ),
          ),
          BlocProvider<TimelineBloc>(
            create: (_) =>
                TimelineBloc(repository: timelineRepository)
                  ..add(const TimelineRequested()),
          ),
        ],
        child: App(
          initialLocation: initialLocation,
          onUserAuthenticated: userRepository.signUpUserIfNeeded,
        ),
      ),
    ),
  );
}
