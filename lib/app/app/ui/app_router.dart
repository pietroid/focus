import 'package:focus/app/content/core/content_screen.dart';
import 'package:focus/app/home/home_screen.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  GoRouter get router => GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/thing/:thingId',
            builder: (context, state) => ContentScreen(
              thingId: int.parse(state.pathParameters['thingId']!),
            ),
          ),
        ],
      );
}
