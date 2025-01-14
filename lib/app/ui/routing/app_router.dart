import 'package:focus/app/core/home/core/home_screen.dart';
import 'package:focus/app/core/thing/ui/thing_screen.dart';
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
            builder: (context, state) => ThingScreen(
              thingId: int.parse(state.pathParameters['thingId']!),
            ),
          ),
        ],
      );
}
