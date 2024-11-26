import 'package:cron/home/shared/presentation/home_screen.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  GoRouter get router => GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
        ],
      );
}
