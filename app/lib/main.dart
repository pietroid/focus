import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/app.dart';
import 'package:focus/bootstrap.dart';
import 'package:focus/firebase_options_development.dart' as dev;
import 'package:focus/firebase_options_production.dart' as prod;
import 'package:subject/subject.dart';
import 'package:user/user.dart';

const _kGoogleSignInClientId = String.fromEnvironment(
  'GOOGLE_SIGN_IN_CLIENT_ID',
);
const _kApiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _kFlavor = String.fromEnvironment('FLAVOR', defaultValue: 'development');

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
  final options = switch (_kFlavor) {
    'production' => prod.DefaultFirebaseOptions.currentPlatform,
    _ => dev.DefaultFirebaseOptions.currentPlatform,
  };

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
  final subjectRepository = SubjectRepository(apiClient: apiClient);
  final subjectBloc = SubjectBloc(subjectRepository: subjectRepository);

  final initialUser = await authRepository.user.first;
  final initialLocation = initialUser == null ? '/auth' : '/';

  if (initialUser != null) {
    subjectBloc.add(const SubjectsRequested());
    await subjectBloc.stream.firstWhere((state) => !state.isLoading);
  }

  await bootstrap(
    () => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => authRepository),
        RepositoryProvider<SubjectRepository>(create: (_) => subjectRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AppBloc>(
            create: (_) => AppBloc(
              authRepository: authRepository,
              initialUser: initialUser,
            ),
          ),
          BlocProvider<SubjectBloc>.value(value: subjectBloc),
        ],
        child: App(
          initialLocation: initialLocation,
          onUserAuthenticated: userRepository.signUpUserIfNeeded,
        ),
      ),
    ),
  );
}
