import 'package:flutter/material.dart';
import 'package:focus/app/app/app.dart';
import 'package:focus/app/common/data/object_box.dart';
import 'package:focus/bootstrap.dart';
import 'package:focus/mocked_design/content/mocked_content_read_screen.dart';
import 'package:focus/mocked_design/content/mocked_content_travel_screen.dart';
import 'package:focus/mocked_design/mocked_home_screen.dart';
import 'package:go_router/go_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  bootstrap(() async {
    final objectBox = await ObjectBox.create();
    return App(
      router: MockedDesignRouter().router,
      objectBox: objectBox,
    );
  });
}

class MockedDesignRouter {
  GoRouter get router => GoRouter(
        initialLocation: '/content-travel',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const MockedHomeScreen(),
          ),
          GoRoute(
            path: '/content-read',
            builder: (context, state) => const MockedContentReadScreen(),
          ),
          GoRoute(
            path: '/content-travel',
            builder: (context, state) => const MockedContentTravelScreen(),
          ),
        ],
      );
}
